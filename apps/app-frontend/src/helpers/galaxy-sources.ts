// Galaxy: search CurseForge and FTB alongside Modrinth (like XMCL does).
// CurseForge needs an API key (free from https://console.curseforge.com).
// FTB uses the public modpacks.ch API (same one XMCL uses).

import { invoke } from '@tauri-apps/api/core'
import { fetch as tauriFetch } from '@tauri-apps/plugin-http'

import { add_project_from_path } from '@/helpers/instance'
import type { InstanceLoader } from '@/helpers/types'

// ---------- CurseForge API key ----------

const CF_KEY_STORAGE = 'galaxy-curseforge-api-key'
// If you get your own key approved, you can paste it here so users don't need one.
const BUILT_IN_CF_KEY = ''

export function getCurseForgeKey(): string {
	try {
		return window.localStorage.getItem(CF_KEY_STORAGE) || BUILT_IN_CF_KEY
	} catch {
		return BUILT_IN_CF_KEY
	}
}

export function setCurseForgeKey(key: string): void {
	try {
		if (key.trim()) {
			window.localStorage.setItem(CF_KEY_STORAGE, key.trim())
		} else {
			window.localStorage.removeItem(CF_KEY_STORAGE)
		}
	} catch {
		// storage blocked
	}
}

// ---------- shared result shape ----------

export type GalaxySource = 'curseforge' | 'ftb'

export type GalaxyContentType = 'mod' | 'modpack' | 'resourcepack' | 'shaderpack'

export interface GalaxyResult {
	source: GalaxySource
	id: number
	name: string
	summary: string
	author: string
	iconUrl: string | null
	downloads: number
	pageUrl: string
	contentType: GalaxyContentType
}

export interface GalaxyFile {
	id: number
	fileName: string
	displayName: string
	gameVersions: string[]
	downloadUrl: string | null
	releaseType: 'release' | 'beta' | 'alpha'
	date: string
}

// ---------- CurseForge ----------

const CF_API = 'https://api.curseforge.com/v1'
const CF_MINECRAFT_GAME_ID = 432

const CF_CLASS_IDS: Record<GalaxyContentType, number> = {
	mod: 6,
	modpack: 4471,
	resourcepack: 12,
	shaderpack: 6552,
}

const CF_LOADER_TYPES: Partial<Record<InstanceLoader, number>> = {
	forge: 1,
	fabric: 4,
	quilt: 5,
	neoforge: 6,
}

const CF_URL_SEGMENT: Record<GalaxyContentType, string> = {
	mod: 'mc-mods',
	modpack: 'modpacks',
	resourcepack: 'texture-packs',
	shaderpack: 'shaders',
}

type CfMod = {
	id: number
	name: string
	slug: string
	summary: string
	downloadCount: number
	logo?: { thumbnailUrl?: string; url?: string } | null
	authors?: { name: string }[]
	links?: { websiteUrl?: string | null } | null
}

type CfFile = {
	id: number
	fileName: string
	displayName: string
	gameVersions: string[]
	downloadUrl: string | null
	releaseType: number
	fileDate: string
}

async function cfGet<T>(path: string): Promise<T> {
	const key = getCurseForgeKey()
	if (!key) {
		throw new Error('Add a CurseForge API key first (see the box at the top of this page).')
	}
	const response = await tauriFetch(`${CF_API}${path}`, {
		headers: { 'x-api-key': key, Accept: 'application/json' },
	})
	if (response.status === 403) {
		throw new Error('CurseForge rejected the API key. Check that it was pasted correctly.')
	}
	if (!response.ok) {
		throw new Error(`CurseForge search failed (${response.status}).`)
	}
	return (await response.json()) as T
}

export async function searchCurseForge(options: {
	query: string
	contentType: GalaxyContentType
	gameVersion?: string
	loader?: InstanceLoader
	page?: number
}): Promise<GalaxyResult[]> {
	const params = new URLSearchParams({
		gameId: String(CF_MINECRAFT_GAME_ID),
		classId: String(CF_CLASS_IDS[options.contentType]),
		searchFilter: options.query,
		sortField: '2', // popularity
		sortOrder: 'desc',
		pageSize: '30',
		index: String((options.page ?? 0) * 30),
	})
	if (options.gameVersion) params.set('gameVersion', options.gameVersion)
	const loaderType = options.loader ? CF_LOADER_TYPES[options.loader] : undefined
	if (loaderType && options.contentType === 'mod') params.set('modLoaderType', String(loaderType))

	const result = await cfGet<{ data: CfMod[] }>(`/mods/search?${params.toString()}`)
	return result.data.map((mod) => ({
		source: 'curseforge' as const,
		id: mod.id,
		name: mod.name,
		summary: mod.summary,
		author: mod.authors?.[0]?.name ?? 'Unknown',
		iconUrl: mod.logo?.thumbnailUrl ?? mod.logo?.url ?? null,
		downloads: mod.downloadCount,
		pageUrl:
			mod.links?.websiteUrl ||
			`https://www.curseforge.com/minecraft/${CF_URL_SEGMENT[options.contentType]}/${mod.slug}`,
		contentType: options.contentType,
	}))
}

export async function getCurseForgeFiles(options: {
	modId: number
	gameVersion?: string
	loader?: InstanceLoader
	contentType: GalaxyContentType
}): Promise<GalaxyFile[]> {
	const params = new URLSearchParams({ pageSize: '50' })
	if (options.gameVersion) params.set('gameVersion', options.gameVersion)
	const loaderType = options.loader ? CF_LOADER_TYPES[options.loader] : undefined
	if (loaderType && options.contentType === 'mod') params.set('modLoaderType', String(loaderType))

	const result = await cfGet<{ data: CfFile[] }>(`/mods/${options.modId}/files?${params.toString()}`)
	return result.data.map((file) => ({
		id: file.id,
		fileName: file.fileName,
		displayName: file.displayName,
		gameVersions: file.gameVersions,
		downloadUrl: file.downloadUrl ?? cfFallbackUrl(file.id, file.fileName),
		releaseType: file.releaseType === 1 ? 'release' : file.releaseType === 2 ? 'beta' : 'alpha',
		date: file.fileDate,
	}))
}

// Some authors turn off third-party downloads, so downloadUrl comes back empty.
// The CDN link can still be built from the file ID (XMCL and Prism do the same).
function cfFallbackUrl(fileId: number, fileName: string): string {
	const id = String(fileId)
	return `https://edge.forgecdn.net/files/${id.slice(0, 4)}/${Number(id.slice(4))}/${encodeURIComponent(fileName)}`
}

// ---------- FTB ----------

const FTB_API = 'https://api.modpacks.ch/public'

type FtbPack = {
	id: number
	name: string
	synopsis: string
	installs: number
	art?: { url: string; type: string }[]
	authors?: { name: string }[]
}

export async function searchFtb(query: string): Promise<GalaxyResult[]> {
	const path = query.trim()
		? `/modpack/search/20?term=${encodeURIComponent(query.trim())}`
		: '/modpack/featured/20'
	const response = await tauriFetch(`${FTB_API}${path}`)
	if (!response.ok) throw new Error(`FTB search failed (${response.status}).`)
	const result = (await response.json()) as { packs?: number[] }
	const ids = (result.packs ?? []).slice(0, 20)

	const packs = await Promise.all(
		ids.map(async (id) => {
			try {
				const res = await tauriFetch(`${FTB_API}/modpack/${id}`)
				return res.ok ? ((await res.json()) as FtbPack) : null
			} catch {
				return null
			}
		}),
	)

	return packs
		.filter((pack): pack is FtbPack => !!pack && !!pack.name)
		.map((pack) => ({
			source: 'ftb' as const,
			id: pack.id,
			name: pack.name,
			summary: pack.synopsis ?? '',
			author: pack.authors?.[0]?.name ?? 'FTB',
			iconUrl: encodeURI(
				pack.art?.find((art) => art.type === 'square')?.url ?? pack.art?.[0]?.url ?? '',
			) || null,
			downloads: pack.installs ?? 0,
			pageUrl: `https://www.feed-the-beast.com/modpacks/${pack.id}`,
			contentType: 'modpack' as const,
		}))
}

// ---------- installing into an instance ----------

export async function installFileToInstance(
	instanceId: string,
	file: GalaxyFile,
	contentType: GalaxyContentType,
): Promise<string> {
	if (!file.downloadUrl) throw new Error('This file has no download link.')
	if (contentType === 'modpack') throw new Error('Modpacks are installed as a new instance.')

	const localPath = await invoke<string>('plugin:galaxy|galaxy_download_to_temp', {
		url: file.downloadUrl,
		fileName: file.fileName,
	})
	return await add_project_from_path(instanceId, localPath, contentType)
}
