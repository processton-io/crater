<template>
  <BaseWizardStep
    title="Installing.."
  >
    <div :class="{ hidden: v$.app_domain.$error }" >
      <div class="flex justify-center items-center h-32">
        <svg class="animate-spin h-10 w-10 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
        </svg>
      </div>
    </div>
    <div
      class="w-full md:w-2/3"
      :class="{ hidden: !v$.app_domain.$error }"
    >
      <BaseInputGroup
        :label="$t('wizard.verify_domain.app_domain')"
        :error="v$.app_domain.$error && v$.app_domain.$errors[0].$message"
        required
      >
        <BaseInput
          v-model="formData.app_domain"
          :invalid="v$.app_domain.$error"
          type="text"
          @input="v$.app_domain.$touch()"
        />
      </BaseInputGroup>
    </div>
    <div
      :class="{ hidden: !v$.app_domain.$error }"
    >
      <p class="mt-4 mb-0 text-sm text-gray-600">Notes:</p>
      <ul class="w-full text-gray-600 list-disc list-inside">
        <li class="text-sm leading-8">
          App domain should not contain
          <b class="inline-block px-1 bg-gray-100 rounded-sm">https://</b> or
          <b class="inline-block px-1 bg-gray-100 rounded-sm">http</b> in front of
          the domain.
        </li>
        <li class="text-sm leading-8">
          If you're accessing the website on a different port, please mention the
          port. For example:
          <b class="inline-block px-1 bg-gray-100">localhost:8080</b>
        </li>
      </ul>
    </div>

    <BaseButton
      :loading="isSaving"
      :disabled="isSaving"
      class="mt-8"
      :class="{ hidden: !v$.app_domain.$error }"
      @click="verifyDomain"
    >
      {{ $t('wizard.verify_domain.verify_now') }}
    </BaseButton>
  </BaseWizardStep>
</template>

<script setup>
import { required, helpers } from '@vuelidate/validators'
import useVuelidate from '@vuelidate/core'
import { ref, inject, computed, reactive, onMounted } from 'vue'
import { useInstallationStore } from '@/scripts/admin/stores/installation'
import { useNotificationStore } from '@/scripts/stores/notification'
import { useI18n } from 'vue-i18n'

const emit = defineEmits(['next'])
onMounted(() => {
  setTimeout(() => {
    verifyDomain()
  }, 2000)
})
const formData = reactive({
  app_domain: window.location.origin.replace(/(^\w+:|^)\/\//, ''),
})
const isSaving = ref(false)
const { t } = useI18n()
const utils = inject('utils')
const isUrl = (value) => utils.checkValidDomainUrl(value)

const installationStore = useInstallationStore()
const notificationStore = useNotificationStore()

const rules = {
  app_domain: {
    required: helpers.withMessage(t('validation.required'), required),
    isUrl: helpers.withMessage(t('validation.invalid_domain_url'), isUrl),
  },
}

const v$ = useVuelidate(
  rules,
  computed(() => formData)
)

async function verifyDomain() {
  v$.value.$touch()

  if (v$.value.$invalid) {
    return true
  }

  isSaving.value = true

  try {
    await installationStore.setInstallationDomain(formData)
    await installationStore.installationLogin()
    let driverRes = await installationStore.checkAutheticated()

    if (driverRes.data) {
      emit('next', 4)
    }

    isSaving.value = false
  } catch (e) {
    notificationStore.showNotification({
      type: 'error',
      message: t('wizard.verify_domain.failed'),
    })

    isSaving.value = false
  }
}
</script>
