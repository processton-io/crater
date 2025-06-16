<template>
  <BaseWizardStep
    title="Installing..."
  >
    <div>
      <div class="flex justify-center items-center h-32">
        <svg class="animate-spin h-10 w-10 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
        </svg>
      </div>
    </div>
    <div class="relative hidden">
      <div
        v-for="(permission, index) in permissions"
        :key="index"
        class="border border-gray-200"
      >
        <div class="grid grid-flow-row grid-cols-3 lg:gap-24 sm:gap-4">
          <div class="col-span-2 p-3">
            {{ permission.folder }}
          </div>
          <div class="p-3 text-right">
            <span
              v-if="permission.isSet"
              class="inline-block w-4 h-4 ml-3 mr-2 rounded-full bg-green-500"
            />
            <span
              v-else
              class="inline-block w-4 h-4 ml-3 mr-2 rounded-full bg-red-500"
            />
            <span>{{ permission.permission }}</span>
          </div>
        </div>
      </div>

      <BaseButton
        v-show="!isFetchingInitialData"
        class="mt-10 hidden"
        :loading="isSaving"
        :disabled="isSaving"
        @click="next"
      >
        <template #left="slotProps">
          <BaseIcon name="ArrowRightIcon" :class="slotProps.class" />
        </template>
        {{ $t('wizard.continue') }}
      </BaseButton>
    </div>
  </BaseWizardStep>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useInstallationStore } from '@/scripts/admin/stores/installation'
import { useDialogStore } from '@/scripts/stores/dialog'
import { useI18n } from 'vue-i18n'

const emit = defineEmits(['next'])

let isFetchingInitialData = ref(false)
let isSaving = ref(false)
let permissions = ref([])
const { tm, t } = useI18n()

const installationStore = useInstallationStore()
const dialogStore = useDialogStore()

onMounted(() => {
  getPermissions()
})

async function getPermissions() {
  isFetchingInitialData.value = true

  const res = await installationStore.fetchInstallationPermissions()

  permissions.value = res.data.permissions.permissions

  if (res.data && res.data.permissions.errors) {
    setTimeout(() => {
      dialogStore
        .openDialog({
          title: tm('wizard.permissions.permission_confirm_title'),
          message: t('wizard.permissions.permission_confirm_desc'),
          yesLabel: 'OK',
          noLabel: 'Cancel',
          variant: 'danger',
          hideNoButton: false,
          size: 'lg',
        })
        .then((res) => {
          if (res.data) {
            isFetchingInitialData.value = false
          }
        })
    }, 500)
  }

  isFetchingInitialData.value = false

  setTimeout(() => {
    next()
  }, 1000)
}

function next() {
  isSaving.value = true
  emit('next')
  isSaving.value = false
}
</script>
