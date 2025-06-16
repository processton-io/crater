<template>
  <BaseWizardStep
    title="Installing.."
  >
    <div>
      <div class="flex justify-center items-center h-32">
        <svg class="animate-spin h-10 w-10 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
        </svg>
      </div>
    </div>
    <div class="w-full md:w-2/3 hidden">
      <div class="mb-6">
        <div
          v-if="phpSupportInfo"
          class="grid grid-flow-row grid-cols-3 p-3 border border-gray-200  lg:gap-24 sm:gap-4"
        >
          <div class="col-span-2 text-sm">
            {{
              $t('wizard.req.php_req_version', {
                version: phpSupportInfo.minimum,
              })
            }}
          </div>
          <div class="text-right">
            {{ phpSupportInfo.current }}
            <span
              v-if="phpSupportInfo.supported"
              class="inline-block w-4 h-4 ml-3 mr-2 bg-green-500 rounded-full"
            />
            <span
              v-else
              class="inline-block w-4 h-4 ml-3 mr-2 bg-red-500 rounded-full"
            />
          </div>
        </div>
        <div v-if="requirements">
          <div
            v-for="(requirement, index) in requirements"
            :key="index"
            class="grid grid-flow-row grid-cols-3 p-3 border border-gray-200  lg:gap-24 sm:gap-4"
          >
            <div class="col-span-2 text-sm">
              {{ index }}
            </div>
            <div class="text-right">
              <span
                v-if="requirement"
                class="inline-block w-4 h-4 ml-3 mr-2 bg-green-500 rounded-full"
              />
              <span
                v-else
                class="inline-block w-4 h-4 ml-3 mr-2 bg-red-500 rounded-full"
              />
            </div>
          </div>
        </div>
      </div>

      <BaseButton v-if="hasNext" @click="next">
        {{ $t('wizard.continue') }}
        <template #left="slotProps">
          <BaseIcon name="ArrowRightIcon" :class="slotProps.class" />
        </template>
      </BaseButton>

      <BaseButton
        v-if="!requirements"
        :loading="isSaving"
        :disabled="isSaving"
        @click="getRequirements"
      >
        {{ $t('wizard.req.check_req') }}
      </BaseButton>
    </div>
  </BaseWizardStep>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useInstallationStore } from '@/scripts/admin/stores/installation.js'

const emit = defineEmits(['next'])

const requirements = ref('')
const phpSupportInfo = ref('')
const isSaving = ref(false)
const isShow = ref(true)

const installationStore = useInstallationStore()

const hasNext = computed(() => {
  if (requirements.value) {
    let isRequired = true
    for (const key in requirements.value) {
      if (!requirements.value[key]) {
        isRequired = false
      }
      return requirements.value && phpSupportInfo.value.supported && isRequired
    }
  }
  return false
})

async function getRequirements() {
  isSaving.value = true
  const response = await installationStore.fetchInstallationRequirements()

  if (response.data) {
    requirements.value = response?.data?.requirements?.requirements?.php
    phpSupportInfo.value = response?.data?.phpSupportInfo
    setTimeout(async () => {
      await next()
    }, 1000)
  }
}

function next() {
  isSaving.value = true
  emit('next')
  isSaving.value = false
}

onMounted(async () => {
  await getRequirements()
})
</script>
