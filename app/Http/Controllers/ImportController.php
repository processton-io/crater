<?php

namespace Crater\Http\Controllers;

use Crater\Models\Setting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ImportController extends Controller
{
    /**
     * Handle the incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function __invoke(Request $request)
    {
        // Prevent timeout for large imports
        set_time_limit(0);
        ini_set('memory_limit', '-1');

        // Check if secondary connection is configured
        $secondaryConfig = config('database.connections.mysql_secondary');
        
        $secondaryConfigured = !empty($secondaryConfig['database']) && !empty($secondaryConfig['username']);

        if (!$secondaryConfigured) {
            return response()->json([
                'error' => 'Secondary database connection is not configured.',
            ], 400);
        }

        // Test secondary connection
        try {
            DB::connection('mysql_secondary')->select('SELECT 1');
        } catch (\Exception $e) {
            return response()->json([
                'error' => 'Could not connect to secondary database: ' . $e->getMessage(),
            ], 500);
        }

        // Empty tables before import, handling foreign key constraints
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        
        // Delete in reverse dependency order to avoid foreign key constraint issues
        \Crater\Models\InvoiceItem::truncate();
        \Crater\Models\Payment::truncate();
        \Crater\Models\Invoice::truncate();
        \Crater\Models\Address::truncate();
        \Crater\Models\Item::truncate();
        \Crater\Models\Customer::truncate();
        \Crater\Models\Company::truncate();
        
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');
        // Import companies
        $importedCompanies = 0;
        $secondaryCompanies = DB::connection('mysql_secondary')->table('companies')->get();
        foreach ($secondaryCompanies as $company) {
            \Crater\Models\Company::updateOrCreate(
                ['id' => $company->id],
                [
                    'name' => $company->name ?? null,
                    'unique_hash' => $company->unique_hash ?? null,
                    'created_at' => $company->created_at ?? null,
                    'updated_at' => $company->updated_at ?? null,
                ]
            );
            $importedCompanies++;
        }
        // Merge customers and contacts from secondary DB into this application's customers table
        $imported = 0;
        $secondaryCustomers = DB::connection('mysql_secondary')->table('customers')->get();
        foreach ($secondaryCustomers as $sc) {
            // Find primary contact for this customer using customer_contacts relation
            $primaryContactId = DB::connection('mysql_secondary')->table('customer_contacts')
                ->where('customer_id', $sc->id)
                ->pluck('contact_id');
            $primaryContact = null;
            if ($primaryContactId->count() > 0) {
                $primaryContact = DB::connection('mysql_secondary')->table('contacts')
                    ->whereIn('id', $primaryContactId)
                    ->where('is_primary_contact', 1)
                    ->first();
                // Fallback: if no primary, get any related contact
                if (!$primaryContact) {
                    $primaryContact = DB::connection('mysql_secondary')->table('contacts')
                        ->whereIn('id', $primaryContactId)
                        ->first();
                }
            }
            $customer = \Crater\Models\Customer::create(
                [
                    'prefix' => $sc->prefix ?? null,
                    'name' => $sc->name,
                    'email' => $primaryContact ? ($primaryContact->email ?? null) : null,
                    'phone' => $sc->phone ?? null,
                    'facebook_id' => $primaryContact ? ($primaryContact->facebook_id ?? null) : null,
                    'google_id' => $primaryContact ? ($primaryContact->google_id ?? null) : null,
                    'github_id' => $primaryContact ? ($primaryContact->github_id ?? null) : null,
                    'website' => $sc->website ?? null,
                    'currency_id' => $sc->currency_id > 72 ? $sc->currency_id - 72 : $sc->currency_id,
                    'company_id' => $sc->company_id ?? null,
                    'creator_id' => $sc->creator_id ?? null,
                    'created_at' => $sc->created_at ?? null,
                    'updated_at' => $sc->updated_at ?? null,
                    'contact_name' => $primaryContact ? ($primaryContact->name ?? null) : null,
                    'company_name' => $primaryContact ? ($primaryContact->company_name ?? null) : null,
                    'password' => $primaryContact ? ($primaryContact->password ?? null) : null,
                    'remember_token' => $primaryContact ? ($primaryContact->remember_token ?? null) : null,
                    'enable_portal' => $primaryContact ? ($primaryContact->enable_portal ?? 0) : 0,
                ]
            );

            $customer->__set('id', $sc->id); // Set the ID to match the secondary DB
            $customer->save();
            $imported++;
        }
        // Import addresses
        $importedAddresses = 0;
        $secondaryAddresses = DB::connection('mysql_secondary')->table('addresses')->get();
        foreach ($secondaryAddresses as $address) {
            $address = \Crater\Models\Address::create(
                [
                    'name' => $address->name ?? null,
                    'address_street_1' => $address->address_street_1 ?? null,
                    'address_street_2' => $address->address_street_2 ?? null,
                    'city' => $address->city ?? null,
                    'state' => $address->state ?? null,
                    'country_id' => $address->country_id ?? null,
                    'zip' => $address->zip ?? null,
                    'phone' => $address->phone ?? null,
                    'fax' => $address->fax ?? null,
                    'type' => $address->type ?? null,
                    'created_at' => $address->created_at ?? null,
                    'updated_at' => $address->updated_at ?? null,
                    'user_id' => $address->user_id ?? null,
                    'company_id' => $address->company_id ?? null,
                    'customer_id' => $address->customer_id ?? null,
                ]
            );
            $address->__set('id', $address->id); // Set the ID to match the secondary DB
            $address->save();
            $importedAddresses++;
        }
        // Import items
        $importedItems = 0;
        $secondaryItems = DB::connection('mysql_secondary')->table('items')->get();
        foreach ($secondaryItems as $item) {
            $item = \Crater\Models\Item::create(
                [
                    'name' => $item->name,
                    'description' => $item->description ?? null,
                    'price' => is_numeric($item->price) ? (int)$item->price : 0,
                    'company_id' => $item->company_id ?? null,
                    'unit_id' => null, // No mapping from remote, set null
                    'created_at' => $item->created_at ?? null,
                    'updated_at' => $item->updated_at ?? null,
                    'creator_id' => $item->creator_id ?? null,
                    'currency_id' => $item->currency_id ?? null,
                    'tax_per_item' => $item->tax_per_item ?? 0,
                ]
            );

            $item->__set('id', $item->id); // Set the ID to match the secondary DB
            $item->save();
            $importedItems++;
        }
        // Import invoices
        $importedInvoices = 0;
        $secondaryInvoices = DB::connection('mysql_secondary')->table('invoices')->get();
        foreach ($secondaryInvoices as $invoice) {
            $inv = \Crater\Models\Invoice::create(
                [
                    'invoice_date' => $invoice->invoice_date,
                    'invoice_number' => $invoice->invoice_number,
                    'reference_number' => $invoice->reference_number ?? null,
                    'status' => $invoice->status,
                    'paid_status' => $invoice->paid_status,
                    'tax_per_item' => $invoice->tax_per_item,
                    'discount_per_item' => $invoice->discount_per_item,
                    'notes' => $invoice->notes ?? null,
                    'discount_type' => $invoice->discount_type ?? null,
                    'discount' => $invoice->discount ?? null,
                    'discount_val' => $invoice->discount_val ?? null,
                    'sub_total' => $invoice->sub_total,
                    'total' => $invoice->total,
                    'tax' => $invoice->tax,
                    'due_amount' => $invoice->due_amount,
                    'sent' => $invoice->sent,
                    'viewed' => $invoice->viewed,
                    'unique_hash' => $invoice->unique_hash ?? null,
                    'company_id' => $invoice->company_id ?? null,
                    'created_at' => $invoice->created_at ?? null,
                    'updated_at' => $invoice->updated_at ?? null,
                    'creator_id' => $invoice->creator_id ?? null,
                    'template_name' => $invoice->template_name ?? null,
                    'customer_id' => $invoice->customer_id ?? null,
                    'recurring_invoice_id' => $invoice->recurring_invoice_id ?? null,
                    'due_date' => $invoice->due_date ?? null,
                    'exchange_rate' => $invoice->exchange_rate ?? null,
                    'base_discount_val' => $invoice->base_discount_val ?? null,
                    'base_sub_total' => $invoice->base_sub_total ?? null,
                    'base_total' => $invoice->base_total ?? null,
                    'base_tax' => $invoice->base_tax ?? null,
                    'base_due_amount' => $invoice->base_due_amount ?? null,
                    'currency_id' => $invoice->currency_id ?? null,
                    'sequence_number' => $invoice->sequence_number ?? null,
                    'customer_sequence_number' => $invoice->customer_sequence_number ?? null,
                    'sales_tax_type' => $invoice->sales_tax_type ?? null,
                    'sales_tax_address_type' => $invoice->sales_tax_address_type ?? null,
                    'overdue' => $invoice->overdue ?? 0,
                ]
            );

            $inv->__set('id', $invoice->id); // Set the ID to match the secondary DB
            $inv->save();
            $importedInvoices++;

            $secondaryInvoiceItems = DB::connection('mysql_secondary')->table('invoice_items')
                ->where('invoice_id',$inv->id)->get();
            foreach ($secondaryInvoiceItems as $item) {
                $invItem = \Crater\Models\InvoiceItem::create(
                    [
                        'name' => $item->name,
                        'discount_type' => $item->discount_type,
                        'price' => $item->price,
                        'quantity' => $item->quantity,
                        'discount' => $item->discount ?? null,
                        'discount_val' => $item->discount_val,
                        'tax' => $item->tax,
                        'total' => $item->total,
                        'item_id' => $item->item_id ?? null,
                        'company_id' => $item->company_id ?? null,
                        'created_at' => $item->created_at ?? null,
                        'updated_at' => $item->updated_at ?? null,
                        'description' => $item->description ?? null,
                        'unit_name' => $item->unit_name ?? null,
                        'invoice_id' => $invoice->id,
                        'recurring_invoice_id' => $item->recurring_invoice_id ?? null,
                        'base_price' => $item->base_price ?? null,
                        'exchange_rate' => $item->exchange_rate ?? null,
                        'base_discount_val' => $item->base_discount_val ?? null,
                        'base_tax' => $item->base_tax ?? null,
                        'base_total' => $item->base_total ?? null,
                    ]
                );
                $invItem->__set('id', $item->id); // Set the ID to match the secondary DB
                $invItem->save();
            }
        }
        
        // Import payments
        $importedPayments = 0;
        $secondaryPayments = DB::connection('mysql_secondary')->table('payments')->get();
        foreach ($secondaryPayments as $payment) {
            \Crater\Models\Payment::updateOrCreate(
                ['id' => $payment->id],
                [
                    'payment_number' => $payment->payment_number,
                    'payment_date' => $payment->payment_date,
                    'notes' => $payment->notes ?? null,
                    'amount' => $payment->amount,
                    'unique_hash' => $payment->unique_hash ?? null,
                    'invoice_id' => $payment->invoice_id ?? null,
                    'company_id' => $payment->company_id ?? null,
                    'payment_method_id' => $payment->payment_method_id ?? null,
                    'created_at' => $payment->created_at ?? null,
                    'updated_at' => $payment->updated_at ?? null,
                    'creator_id' => $payment->creator_id ?? null,
                    'customer_id' => $payment->customer_id ?? null,
                    'exchange_rate' => $payment->exchange_rate ?? null,
                    'base_amount' => $payment->base_amount ?? null,
                    'currency_id' => $payment->currency_id ?? null,
                    'sequence_number' => $payment->sequence_number ?? null,
                    'customer_sequence_number' => $payment->customer_sequence_number ?? null,
                    'transaction_id' => $payment->transaction_id ?? null,
                ]
            );
            $importedPayments++;
        }

        $version = Setting::getSetting('version');

        return response()->json([
            'version' => $version,
            'message' => 'Secondary DB connection successful. Import completed.',
            'imported_total_customers' => $imported,
            'imported_total_companies' => $importedCompanies,
            'imported_total_addresses' => $importedAddresses,
            'imported_total_items' => $importedItems,
            'imported_total_invoices' => $importedInvoices,
            'imported_total_payments' => $importedPayments,
        ]);
    }
}
