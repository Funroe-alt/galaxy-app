<script setup lang="ts">
// Galaxy: live status of the servers you've played on (online, players, ping),
// with a one-click Join. Used in the right sidebar and on the Servers page.
import { onBeforeUnmount, onMounted, ref } from 'vue'

import {
	get_recent_worlds,
	get_server_status,
	type ServerStatus,
	start_join_server,
} from '@/helpers/worlds'

const props = withDefaults(defineProps<{ limit?: number; showTitle?: boolean }>(), {
	limit: 5,
	showTitle: true,
})

type Row = {
	name: string
	address: string
	instanceId: string
	status: ServerStatus | null
	loading: boolean
	error: boolean
}

const rows = ref<Row[]>([])
const loaded = ref(false)
const joinError = ref<string | null>(null)
let timer: ReturnType<typeof setInterval> | undefined

async function load() {
	try {
		const worlds = await get_recent_worlds(60)
		const seen = new Set<string>()
		const next: Row[] = []
		for (const world of worlds) {
			if (world.type !== 'server') continue
			const key = world.address.toLowerCase()
			if (seen.has(key)) continue
			seen.add(key)
			const old = rows.value.find((r) => r.address.toLowerCase() === key)
			next.push({
				name: world.name,
				address: world.address,
				instanceId: world.instance_id,
				status: old?.status ?? null,
				loading: !old,
				error: false,
			})
			if (next.length >= props.limit) break
		}
		rows.value = next
	} catch {
		rows.value = []
	} finally {
		loaded.value = true
	}
	await Promise.all(rows.value.map(ping))
}

async function ping(row: Row) {
	try {
		row.status = await get_server_status(row.address)
		row.error = false
	} catch {
		row.status = null
		row.error = true
	} finally {
		row.loading = false
	}
}

async function join(row: Row) {
	joinError.value = null
	try {
		await start_join_server(row.instanceId, row.address)
	} catch (e) {
		joinError.value = e instanceof Error ? e.message : String(e)
	}
}

defineExpose({ reload: load })

onMounted(() => {
	void load()
	timer = setInterval(() => void load(), 60_000)
})
onBeforeUnmount(() => {
	if (timer) clearInterval(timer)
})
</script>

<template>
	<div class="flex flex-col gap-2">
		<h3 v-if="showTitle" class="m-0 text-base font-medium text-primary">Servers</h3>
		<p v-if="loaded && rows.length === 0" class="m-0 text-sm text-secondary">
			Servers you join will show up here with their status.
		</p>
		<div v-for="row in rows" :key="row.address" class="galaxy-server">
			<img
				v-if="row.status?.favicon"
				:src="row.status.favicon"
				:alt="row.name"
				class="galaxy-server-icon"
			/>
			<div v-else class="galaxy-server-icon" />
			<div class="flex min-w-0 flex-1 flex-col">
				<span class="truncate font-semibold text-contrast">{{ row.name }}</span>
				<span class="flex items-center gap-1 text-xs text-secondary">
					<span
						class="galaxy-dot"
						:class="row.loading ? 'loading' : row.status ? 'online' : 'offline'"
					/>
					<template v-if="row.loading">Checking…</template>
					<template v-else-if="row.status">
						{{ row.status.players?.online ?? 0 }}/{{ row.status.players?.max ?? 0 }} online
						<template v-if="row.status.ping"> · {{ row.status.ping }} ms</template>
					</template>
					<template v-else>Offline</template>
				</span>
			</div>
			<button class="galaxy-join" :disabled="!row.status" @click="join(row)">Join</button>
		</div>
		<p v-if="joinError" class="m-0 text-xs text-red">{{ joinError }}</p>
	</div>
</template>

<style scoped lang="scss">
.galaxy-server {
	display: flex;
	align-items: center;
	gap: 0.6rem;
	padding: 0.4rem;
	border-radius: var(--radius-md);

	&:hover {
		background: var(--color-button-bg);
	}
}

.galaxy-server-icon {
	width: 2.25rem;
	height: 2.25rem;
	flex-shrink: 0;
	border-radius: var(--radius-sm);
	background: var(--color-button-bg);
	image-rendering: pixelated;
}

.galaxy-dot {
	width: 0.5rem;
	height: 0.5rem;
	border-radius: 999px;
	background: var(--color-secondary, #888);

	&.online {
		background: #22c55e;
	}
	&.offline {
		background: #ef4444;
	}
	&.loading {
		background: #a1a1aa;
	}
}

.galaxy-join {
	border: none;
	border-radius: var(--radius-md);
	padding: 0.3rem 0.7rem;
	font: inherit;
	font-weight: 700;
	font-size: 0.8rem;
	cursor: pointer;
	background: var(--color-brand);
	color: #fff;

	&:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}
}
</style>
