<script setup lang="ts">
// Galaxy: one place for servers - find them, keep track of them, and make a
// modpack players can install to join yours.
import { Button } from '@modrinth/ui'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import ExportModal from '@/components/ui/ExportModal.vue'
import GalaxyServerStatus from '@/components/ui/GalaxyServerStatus.vue'
import { list as listInstances } from '@/helpers/instance'
import type { GameInstance } from '@/helpers/types'
import { add_server_to_instance } from '@/helpers/worlds'

const router = useRouter()

const instances = ref<GameInstance[]>([])
const addInstanceId = ref('')
const packInstanceId = ref('')
const serverName = ref('')
const serverAddress = ref('')
const addError = ref<string | null>(null)
const addDone = ref<string | null>(null)

const statusList = ref<{ reload: () => Promise<void> } | null>(null)
const exportModal = ref<{ show: () => void } | null>(null)
const packInstance = computed(() => instances.value.find((i) => i.id === packInstanceId.value))

async function addServer() {
	addError.value = null
	addDone.value = null
	if (!addInstanceId.value || !serverAddress.value.trim()) {
		addError.value = 'Pick an instance and type the server address.'
		return
	}
	try {
		const name = serverName.value.trim() || serverAddress.value.trim()
		await add_server_to_instance(addInstanceId.value, name, serverAddress.value.trim(), 'prompt')
		addDone.value = `Added ${name}.`
		serverName.value = ''
		serverAddress.value = ''
		await statusList.value?.reload()
	} catch (e) {
		addError.value = e instanceof Error ? e.message : String(e)
	}
}

function exportPack() {
	exportModal.value?.show()
}

onMounted(async () => {
	try {
		instances.value = await listInstances()
		addInstanceId.value = instances.value[0]?.id ?? ''
		packInstanceId.value = instances.value[0]?.id ?? ''
	} catch {
		instances.value = []
	}
})
</script>

<template>
	<div class="flex flex-col gap-5 p-6">
		<h1 class="m-0 text-2xl font-extrabold text-contrast">Servers</h1>

		<!-- Find servers -->
		<section class="galaxy-card flex flex-col gap-2">
			<h2 class="m-0 text-lg font-bold text-contrast">Find servers</h2>
			<p class="m-0 text-secondary">
				Browse servers listed on Modrinth. Servers that use a modpack set it up for you when you
				click Play.
			</p>
			<div><Button @click="router.push('/browse/server')">Browse servers</Button></div>
		</section>

		<!-- My servers -->
		<section class="galaxy-card flex flex-col gap-3">
			<h2 class="m-0 text-lg font-bold text-contrast">My servers</h2>
			<GalaxyServerStatus ref="statusList" :limit="50" :show-title="false" />
			<div class="flex flex-wrap items-center gap-2">
				<select v-model="addInstanceId" class="galaxy-input">
					<option v-if="instances.length === 0" value="">No instances yet</option>
					<option v-for="inst in instances" :key="inst.id" :value="inst.id">{{ inst.name }}</option>
				</select>
				<input v-model="serverName" class="galaxy-input" placeholder="Name (optional)" />
				<input
					v-model="serverAddress"
					class="galaxy-input flex-1"
					placeholder="Server address, e.g. play.example.net"
					@keyup.enter="addServer"
				/>
				<Button @click="addServer">Add server</Button>
			</div>
			<p v-if="addError" class="m-0 text-sm text-red">{{ addError }}</p>
			<p v-if="addDone" class="m-0 text-sm text-green">{{ addDone }}</p>
		</section>

		<!-- Make a server pack -->
		<section class="galaxy-card flex flex-col gap-2">
			<h2 class="m-0 text-lg font-bold text-contrast">Make a pack for your server</h2>
			<p class="m-0 text-secondary">
				Set up an instance with the mods your server uses, then export it as a <b>.mrpack</b>.
				Players drag that file into Galaxy (or Modrinth / Prism) and get the exact same mods. To list
				your server on Modrinth, upload the pack to a server project on modrinth.com.
			</p>
			<div class="flex flex-wrap items-center gap-2">
				<select v-model="packInstanceId" class="galaxy-input">
					<option v-if="instances.length === 0" value="">No instances yet</option>
					<option v-for="inst in instances" :key="inst.id" :value="inst.id">
						{{ inst.name }} ({{ inst.loader }} {{ inst.game_version }})
					</option>
				</select>
				<Button :disabled="!packInstance" @click="exportPack">Export pack</Button>
			</div>
			<ExportModal v-if="packInstance" :key="packInstance.id" ref="exportModal" :instance="packInstance" />
		</section>
	</div>
</template>

<style scoped lang="scss">
.galaxy-card {
	background: var(--color-raised-bg);
	border-radius: var(--radius-lg);
	padding: 1rem;
}

.galaxy-input {
	background: var(--color-button-bg);
	color: var(--color-contrast);
	border: none;
	border-radius: var(--radius-md);
	padding: 0.6rem 0.8rem;
	font: inherit;
}
</style>
