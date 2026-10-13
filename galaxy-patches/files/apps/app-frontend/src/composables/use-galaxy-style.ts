import { reactive, ref, watch } from 'vue'

// Galaxy's own look-and-feel options (the XMCL-style "feathers").
// Everything here is saved in the launcher's local storage and applied instantly,
// so none of it touches Modrinth's settings system.

export const DEFAULT_ACCENT = '#8b5cf6'

export const FONT_OPTIONS = [
	{ id: 'default', label: 'Default (Inter)', css: '' },
	{ id: 'segoe', label: 'Segoe UI', css: "'Segoe UI', sans-serif" },
	{ id: 'arial', label: 'Arial', css: 'Arial, sans-serif' },
	{ id: 'verdana', label: 'Verdana', css: 'Verdana, sans-serif' },
	{ id: 'trebuchet', label: 'Trebuchet MS', css: "'Trebuchet MS', sans-serif" },
	{ id: 'georgia', label: 'Georgia', css: 'Georgia, serif' },
	{ id: 'consolas', label: 'Consolas (mono)', css: 'Consolas, monospace' },
	{ id: 'custom', label: 'Custom (type a font name)', css: '' },
] as const

export type FontId = (typeof FONT_OPTIONS)[number]['id']

type GalaxyStyle = {
	prideTheme: boolean
	prideAutoJune: boolean
	accent: string
	backgroundBlur: number // px
	backgroundDim: number // 0-90 %
	panelOpacity: number // 20-100 %
	glassPanels: boolean
	font: FontId
	customFont: string
}

const DEFAULTS: GalaxyStyle = {
	prideTheme: false,
	prideAutoJune: true,
	accent: DEFAULT_ACCENT,
	backgroundBlur: 8,
	backgroundDim: 40,
	panelOpacity: 75,
	glassPanels: true,
	font: 'default',
	customFont: '',
}

const STYLE_KEY = 'galaxy-style'
const BG_IMAGE_KEY = 'galaxy-background-image'

// Keys from the first version of the pride toggle, so nobody loses their setting.
const OLD_PRIDE_KEY = 'galaxy-pride-theme'
const OLD_PRIDE_JUNE_KEY = 'galaxy-pride-auto-june'

function readStorage(key: string): string | null {
	try {
		return window.localStorage.getItem(key)
	} catch {
		return null
	}
}

function writeStorage(key: string, value: string | null): boolean {
	try {
		if (value === null) {
			window.localStorage.removeItem(key)
		} else {
			window.localStorage.setItem(key, value)
		}
		return true
	} catch {
		return false // storage blocked or full
	}
}

function loadStyle(): GalaxyStyle {
	const loaded: GalaxyStyle = { ...DEFAULTS }
	const raw = readStorage(STYLE_KEY)
	if (raw) {
		try {
			Object.assign(loaded, JSON.parse(raw))
		} catch {
			// corrupted, fall back to defaults
		}
	} else {
		const oldPride = readStorage(OLD_PRIDE_KEY)
		const oldJune = readStorage(OLD_PRIDE_JUNE_KEY)
		if (oldPride !== null) loaded.prideTheme = oldPride === 'true'
		if (oldJune !== null) loaded.prideAutoJune = oldJune === 'true'
	}
	return loaded
}

const style = reactive<GalaxyStyle>(loadStyle())
const backgroundImage = ref<string | null>(readStorage(BG_IMAGE_KEY))

// ---------- applying the style to the page ----------

const root = document.documentElement

function ensureBackgroundLayer(): HTMLDivElement {
	let layer = document.getElementById('galaxy-background') as HTMLDivElement | null
	if (!layer) {
		layer = document.createElement('div')
		layer.id = 'galaxy-background'
		document.body.prepend(layer)
	}
	return layer
}

function applyStyle() {
	// Pride
	const isJune = new Date().getMonth() === 5 // 0 = January, so 5 = June
	root.classList.toggle('pride-month', style.prideTheme || (style.prideAutoJune && isJune))

	// Accent colour
	if (style.accent && style.accent.toLowerCase() !== DEFAULT_ACCENT) {
		root.style.setProperty('--color-brand', style.accent)
		root.style.setProperty(
			'--color-brand-highlight',
			`color-mix(in srgb, ${style.accent} 25%, transparent)`,
		)
		root.style.setProperty('--color-brand-shadow', `color-mix(in srgb, ${style.accent} 70%, transparent)`)
	} else {
		root.style.removeProperty('--color-brand')
		root.style.removeProperty('--color-brand-highlight')
		root.style.removeProperty('--color-brand-shadow')
	}

	// Font
	const font = FONT_OPTIONS.find((option) => option.id === style.font)
	const fontCss = style.font === 'custom' ? style.customFont.trim() : (font?.css ?? '')
	if (fontCss) {
		root.style.setProperty('--galaxy-font', fontCss)
		root.classList.add('galaxy-custom-font')
	} else {
		root.style.removeProperty('--galaxy-font')
		root.classList.remove('galaxy-custom-font')
	}

	// Background image
	const layer = ensureBackgroundLayer()
	if (backgroundImage.value) {
		root.classList.add('galaxy-has-bg')
		layer.style.backgroundImage = `url("${backgroundImage.value}")`
		root.style.setProperty('--galaxy-bg-blur', `${style.backgroundBlur}px`)
		root.style.setProperty('--galaxy-bg-dim', `${style.backgroundDim / 100}`)
		root.style.setProperty('--galaxy-panel-opacity', `${style.panelOpacity}%`)
		root.classList.toggle('galaxy-glass', style.glassPanels)
	} else {
		root.classList.remove('galaxy-has-bg', 'galaxy-glass')
		layer.style.backgroundImage = ''
	}
}

watch(
	style,
	(value) => {
		writeStorage(STYLE_KEY, JSON.stringify(value))
		applyStyle()
	},
	{ deep: true },
)

watch(backgroundImage, applyStyle)

if (document.body) {
	applyStyle()
} else {
	window.addEventListener('DOMContentLoaded', applyStyle, { once: true })
}

// ---------- background image helpers ----------

// Shrinks the picked image so it fits in local storage (about 5 MB max).
function shrinkImage(file: File, maxSize = 1920): Promise<string> {
	return new Promise((resolve, reject) => {
		const url = URL.createObjectURL(file)
		const img = new Image()
		img.onload = () => {
			const scale = Math.min(1, maxSize / Math.max(img.width, img.height))
			const canvas = document.createElement('canvas')
			canvas.width = Math.round(img.width * scale)
			canvas.height = Math.round(img.height * scale)
			const ctx = canvas.getContext('2d')
			if (!ctx) {
				URL.revokeObjectURL(url)
				reject(new Error('Could not read that image.'))
				return
			}
			ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
			URL.revokeObjectURL(url)
			resolve(canvas.toDataURL('image/jpeg', 0.85))
		}
		img.onerror = () => {
			URL.revokeObjectURL(url)
			reject(new Error('That file is not an image the launcher can open.'))
		}
		img.src = url
	})
}

async function setBackgroundFromFile(file: File): Promise<void> {
	const dataUrl = await shrinkImage(file)
	if (!writeStorage(BG_IMAGE_KEY, dataUrl)) {
		throw new Error('That image is too big to save. Try a smaller one.')
	}
	backgroundImage.value = dataUrl
}

function clearBackground(): void {
	writeStorage(BG_IMAGE_KEY, null)
	backgroundImage.value = null
}

function resetStyle(): void {
	Object.assign(style, DEFAULTS)
	clearBackground()
}

export function useGalaxyStyle() {
	return { style, backgroundImage, setBackgroundFromFile, clearBackground, resetStyle }
}
