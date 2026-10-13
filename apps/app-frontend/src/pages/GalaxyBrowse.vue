<script setup lang="ts">
import { DownloadIcon, ExternalIcon, SearchIcon } from '@modrinth/assets'
import { Button } from '@modrinth/ui'
import { openUrl } from '@tauri-apps/plugin-opener'
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
	type GalaxyContentType,
	type GalaxyResult,
	type GalaxySource,
	getCurseForgeFiles,
	getCurseForgeKey,
	installFileToInstance,
	searchCurseForge,
	searchFtb,
	setCurseForgeKey,
} from '@/helpers/galaxy-sources.ts'
import { list as listInstances } from '@/helpers/instance'
import type { GameInstance } from '@/helpers/types'

const router = useRouter()

const source = ref<GalaxySource>('curseforge')
const contentType = ref<GalaxyContentType>('mod')
const query = ref('')
const results = ref<GalaxyResult[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const status = ref<string | null>(null)
const busyId = ref<number | null>(null)
const page = ref(0)

const instances = ref<GameInstance[]>([])
const instanceId = ref<string>('')
const selectedInstance = computed(() => instances.value.find((i) => i.id === instanceId.value))
const matchInstance = ref(true)

const cfKey = ref(getCurseForgeKey())
const cfKeyInput = ref('')
const needsKey = computed(() => source.value === 'curseforge' && !cfKey.value)

const CONTENT_TYPES: { id: GalaxyContentType; label: string }[] = [
	{ id: 'mod', label: 'Mods' },
	{ id: 'modpack', label: 'Modpacks' },
	{ id: 'resourcepack', label: 'Resource packs' },
	{ id: 'shaderpack', label: 'Shaders' },
]

function saveKey() {
	setCurseForgeKey(cfKeyInput.value)
	cfKey.value = getCurseForgeKey()
	cfKeyInput.value = ''
	if (cfKey.value) void runSearch(true)
}

function formatDownloads(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
	if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
	return String(n)
}

async function runSearch(reset = false) {
	if (reset) page.value = 0
	error.value = null
	status.value = null
	if (needsKey.value) {
		results.value = []
		return
	}
	loading.value = true
	try {
		if (source.value === 'ftb') {
			results.value = await searchFtb(query.value)
		} else {
			const useFilters = matchInstance.value && selectedInstance.value
			results.value = await searchCurseForge({
				query: query.value,
				contentType: contentType.value,
				gameVersion: useFilters ? selectedInstance.value?.game_version : undefined,
				loader: useFilters ? selectedInstance.value?.loader : undefined,
				page: page.value,
			})
		}
	} catch (e) {
		results.value = []
		error.value = e instanceof Error ? e.message : String(e)
	} finally {
		loading.value = false
	}
}

async function install(result: GalaxyResult) {
	const instance = selectedInstance.value
	if (!instance) {
		error.value = 'Pick an instance to install into first.'
		return
	}
	error.value = null
	status.value = null
	busyId.value = result.id
	try {
		const files = await getCurseForgeFiles({
			modId: result.id,
			gameVersion: instance.game_version,
			loader: instance.loader,
			contentType: result.contentType,
		})
		const file = files.find((f) => f.releaseType === 'release') ?? files[0]
		if (!file) {
			throw new Error(
				`${result.name} has no file for ${instance.game_version} ${instance.loader}.`,
			)
		}
		await installFileToInstance(instance.id, file, result.contentType)
		status.value = `Installed ${file.displayName} into ${instance.name}.`
	} catch (e) {
		error.value = e instanceof Error ? e.message : String(e)
	} finally {
		busyId.value = null
	}
}

function openModrinth() {
	router.push(`/browse/${contentType.value === 'shaderpack' ? 'shader' : contentType.value}`)
}

watch([source, contentType], () => runSearch(true))
watch([instanceId, matchInstance], () => {
	if (source.value === 'curseforge') void runSearch(true)
})

onMounted(async () => {
	try {
		instances.value = await listInstances()
		instanceId.value = instances.value[0]?.id ?? ''
	} catch {
		instances.value = []
	}
	void runSearch(true)
})
</script>

<template>
	<div class="flex flex-col gap-4 p-6">
		<div class="flex flex-wrap items-center justify-between gap-3">
			<h1 class="m-0 text-2xl font-extrabold text-contrast">Find content</h1>
			<div class="galaxy-tabs">
				<button :class="{ active: false }" @click="openModrinth">Modrinth</button>
				<button :class="{ active: source === 'curseforge' }" @click="source = 'curseforge'">
					CurseForge
				</button>
				<button :class="{ active: source === 'ftb' }" @click="source = 'ftb'">FTB</button>
			</div>
		</div>

		<!-- CurseForge key -->
		<div v-if="needsKey" class="galaxy-card flex flex-col gap-2">
			<h2 class="m-0 text-lg font-bold text-contrast">CurseForge needs an API key</h2>
			<p class="m-0 text-secondary">
				CurseForge only allows searching with a free key. Get one at
				<a class="text-link" href="#" @click.prevent="openUrl('https://console.curseforge.com')"
					>console.curseforge.com</a
				>, then paste it here. It's stored only on this PC.
			</p>
			<div class="flex flex-wrap gap-2">
				<input
					v-model="cfKeyInput"
					type="password"
					class="galaxy-input flex-1"
					placeholder="Paste your CurseForge API key"
					@keyup.enter="saveKey"
				/>
				<Button :disabled="!cfKeyInput.trim()" @click="saveKey">Save key</Button>
			</div>
		</div>

		<!-- Search bar -->
		<div class="flex flex-wrap items-center gap-2">
			<div class="relative flex-1 min-w-[16rem]">
				<SearchIcon class="absolute left-3 top-1/2 -translate-y-1/2 text-secondary" />
				<input
					v-model="query"
					type="text"
					class="galaxy-input w-full pl-10"
					:placeholder="source === 'ftb' ? 'Search FTB modpacks…' : 'Search CurseForge…'"
					@keyup.enter="runSearch(true)"
				/>
			</div>
			<select v-if="source === 'curseforge'" v-model="contentType" class="galaxy-input">
				<option v-for="type in CONTENT_TYPES" :key="type.id" :value="type.id">
					{{ type.label }}
				</option>
			</select>
			<Button @click="runSearch(true)">Search</Button>
		</div>

		<!-- Instance picker -->
		<div
			v-if="source === 'curseforge' && contentType !== 'modpack'"
			class="flex flex-wrap items-center gap-3 text-secondary"
		>
			<span>Install into</span>
			<select v-model="instanceId" class="galaxy-input">
				<option v-if="instances.length === 0" value="">No instances yet</option>
				<option v-for="inst in instances" :key="inst.id" :value="inst.id">
					{{ inst.name }} ({{ inst.loader }} {{ inst.game_version }})
				</option>
			</select>
			<label class="flex items-center gap-2 cursor-pointer">
				<input v-model="matchInstance" type="checkbox" />
				Only show content for this instance
			</label>
		</div>

		<p v-if="source === 'ftb'" class="m-0 text-sm text-secondary">
			FTB modpacks open on the FTB website for now. One-click FTB installs are coming later.
		</p>
		<p v-if="source === 'curseforge' && contentType === 'modpack'" class="m-0 text-sm text-secondary">
			CurseForge modpacks open on CurseForge for now. One-click modpack installs are coming later.
		</p>

		<p v-if="error" class="m-0 font-semibold text-red">{{ error }}</p>
		<p v-if="status" class="m-0 font-semibold text-green">{{ status }}</p>

		<p v-if="loading" class="m-0 text-secondary">Searching…</p>
		<p v-else-if="!error && !needsKey && results.length === 0" class="m-0 text-secondary">
			Nothing found.
		</p>

		<!-- Results -->
		<div class="flex flex-col gap-2">
			<div v-for="result in results" :key="`${result.source}-${result.id}`" class="galaxy-card galaxy-result">
				<img
					v-if="result.iconUrl"
					:src="result.iconUrl"
					:alt="result.name"
					class="galaxy-icon"
					loading="lazy"
				/>
				<div v-else class="galaxy-icon" />
				<div class="flex min-w-0 flex-1 flex-col gap-1">
					<div class="flex flex-wrap items-baseline gap-2">
						<span class="text-lg font-bold text-contrast">{{ result.name }}</span>
						<span class="text-sm text-secondary">by {{ result.author }}</span>
						<span class="galaxy-badge">{{ result.source === 'ftb' ? 'FTB' : 'CurseForge' }}</span>
					</div>
					<p class="m-0 line-clamp-2 text-secondary">{{ result.summary }}</p>
					<span class="text-sm text-secondary">{{ formatDownloads(result.downloads) }} downloads</span>
				</div>
				<div class="flex shrink-0 flex-col gap-2">
					<Button
						v-if="result.source === 'curseforge' && result.contentType !== 'modpack'"
						:disabled="busyId !== null || !selectedInstance"
						@click="install(result)"
					>
						<DownloadIcon />
						{{ busyId === result.id ? 'Installing…' : 'Install' }}
					</Button>
					<Button type="quiet" @click="openUrl(result.pageUrl)">
						<ExternalIcon />
						Open page
					</Button>
				</div>
			</div>
		</div>

		<div
			v-if="source === 'curseforge' && results.length === 30"
			class="flex justify-center gap-2"
		>
			<Button :disabled="page === 0 || loading" @click="(page--, runSearch())">Previous</Button>
			<Button :disabled="loading" @click="(page++, runSearch())">Next</Button>
		</div>
	</div>
</template>

<style scoped lang="scss">
.galaxy-tabs {
	display: flex;
	gap: 0.25rem;
	padding: 0.25rem;
	border-radius: var(--radius-lg);
	background: var(--color-button-bg);

	button {
		border: none;
		background: transparent;
		color: var(--color-base);
		font: inherit;
		font-weight: 600;
		padding: 0.4rem 0.9rem;
		border-radius: var(--radius-md);
		cursor: pointer;

		&.active {
			background: var(--color-brand);
			color: var(--color-accent-contrast, #fff);
		}
	}
}

.galaxy-card {
	background: var(--color-raised-bg);
	border-radius: var(--radius-lg);
	padding: 1rem;
}

.galaxy-result {
	display: flex;
	align-items: center;
	gap: 1rem;
}

.galaxy-icon {
	width: 4rem;
	height: 4rem;
	flex-shrink: 0;
	border-radius: var(--radius-md);
	object-fit: cover;
	background: var(--color-button-bg);
}

.galaxy-badge {
	font-size: 0.75rem;
	font-weight: 700;
	padding: 0.1rem 0.5rem;
	border-radius: 999px;
	background: var(--color-brand-highlight);
	color: var(--color-brand);
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
