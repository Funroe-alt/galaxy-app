<script setup lang="ts">
import { Button, Slider, Toggle } from '@modrinth/ui'
import { ref } from 'vue'

import { DEFAULT_ACCENT, FONT_OPTIONS, useGalaxyStyle } from '@/composables/use-galaxy-style.ts'

const { style, backgroundImage, setBackgroundFromFile, clearBackground, resetStyle } =
	useGalaxyStyle()

const fileInput = ref<HTMLInputElement | null>(null)
const imageError = ref<string | null>(null)
const loadingImage = ref(false)

const ACCENT_PRESETS = ['#8b5cf6', '#6366f1', '#3b82f6', '#06b6d4', '#10b981', '#f59e0b', '#ef4444', '#ec4899']

async function onImagePicked(event: Event) {
	const input = event.target as HTMLInputElement
	const file = input.files?.[0]
	input.value = '' // so picking the same file again still works
	if (!file) return

	imageError.value = null
	loadingImage.value = true
	try {
		await setBackgroundFromFile(file)
	} catch (error) {
		imageError.value = error instanceof Error ? error.message : 'Could not use that image.'
	} finally {
		loadingImage.value = false
	}
}
</script>

<template>
	<div class="mt-6 flex flex-col gap-5">
		<div class="flex items-center justify-between gap-4">
			<h2 class="m-0 text-lg font-extrabold text-contrast">Galaxy</h2>
			<Button type="quiet" @click="resetStyle">Reset Galaxy style</Button>
		</div>

		<!-- Accent colour -->
		<div class="flex flex-col gap-2">
			<div>
				<h3 class="m-0 text-base font-semibold text-contrast">Accent color</h3>
				<p class="m-0 text-sm text-secondary">Buttons, highlights and the loading bar.</p>
			</div>
			<div class="flex flex-wrap items-center gap-2">
				<button
					v-for="color in ACCENT_PRESETS"
					:key="color"
					class="galaxy-swatch"
					:class="{ selected: style.accent.toLowerCase() === color }"
					:style="{ backgroundColor: color }"
					:aria-label="`Use accent ${color}`"
					@click="style.accent = color"
				/>
				<label class="galaxy-swatch galaxy-swatch-custom" title="Pick any color">
					<input v-model="style.accent" type="color" aria-label="Custom accent color" />
				</label>
				<Button
					v-if="style.accent.toLowerCase() !== DEFAULT_ACCENT"
					type="quiet"
					@click="style.accent = DEFAULT_ACCENT"
				>
					Reset
				</Button>
			</div>
		</div>

		<!-- Background image -->
		<div class="flex flex-col gap-2">
			<div>
				<h3 class="m-0 text-base font-semibold text-contrast">Background image</h3>
				<p class="m-0 text-sm text-secondary">Shows behind the whole launcher.</p>
			</div>
			<div class="flex flex-wrap items-center gap-3">
				<div
					v-if="backgroundImage"
					class="galaxy-bg-preview"
					:style="{ backgroundImage: `url(&quot;${backgroundImage}&quot;)` }"
				/>
				<Button :disabled="loadingImage" @click="fileInput?.click()">
					{{ loadingImage ? 'Loading…' : backgroundImage ? 'Change image' : 'Choose image' }}
				</Button>
				<Button v-if="backgroundImage" type="quiet" @click="clearBackground">Remove</Button>
				<input
					ref="fileInput"
					type="file"
					accept="image/png,image/jpeg,image/webp,image/gif"
					class="hidden"
					@change="onImagePicked"
				/>
			</div>
			<p v-if="imageError" class="m-0 text-sm text-red">{{ imageError }}</p>
		</div>

		<template v-if="backgroundImage">
			<div class="flex flex-col gap-2">
				<h3 class="m-0 text-base font-semibold text-contrast">Background blur</h3>
				<Slider v-model="style.backgroundBlur" :min="0" :max="30" :step="1" unit="px" />
			</div>
			<div class="flex flex-col gap-2">
				<h3 class="m-0 text-base font-semibold text-contrast">Background darkness</h3>
				<Slider v-model="style.backgroundDim" :min="0" :max="90" :step="5" unit="%" />
			</div>
			<div class="flex flex-col gap-2">
				<div>
					<h3 class="m-0 text-base font-semibold text-contrast">Panel opacity</h3>
					<p class="m-0 text-sm text-secondary">Lower shows more of the background.</p>
				</div>
				<Slider v-model="style.panelOpacity" :min="20" :max="100" :step="5" unit="%" />
			</div>
			<div class="flex items-center justify-between gap-4">
				<div>
					<h3 class="m-0 text-base font-semibold text-contrast">Frosted glass panels</h3>
					<p class="m-0 text-sm text-secondary">
						Blurs the background behind panels. Turn off on slower PCs.
					</p>
				</div>
				<Toggle id="galaxy-glass" v-model="style.glassPanels" />
			</div>
		</template>

		<!-- Font -->
		<div class="flex flex-col gap-2">
			<div>
				<h3 class="m-0 text-base font-semibold text-contrast">Font</h3>
				<p class="m-0 text-sm text-secondary">Custom fonts must be installed on this PC.</p>
			</div>
			<div class="flex flex-wrap items-center gap-2">
				<select v-model="style.font" class="galaxy-select">
					<option v-for="font in FONT_OPTIONS" :key="font.id" :value="font.id">
						{{ font.label }}
					</option>
				</select>
				<input
					v-if="style.font === 'custom'"
					v-model.lazy="style.customFont"
					type="text"
					class="galaxy-select"
					placeholder="e.g. Comic Sans MS"
				/>
			</div>
		</div>

		<!-- Pride -->
		<div class="flex items-center justify-between gap-4">
			<div>
				<h3 class="m-0 text-base font-semibold text-contrast">Pride theme</h3>
				<p class="m-0 text-sm text-secondary">Rainbow logo and accents across the launcher.</p>
			</div>
			<Toggle id="galaxy-pride-theme" v-model="style.prideTheme" />
		</div>
		<div class="flex items-center justify-between gap-4">
			<div>
				<h3 class="m-0 text-base font-semibold text-contrast">Turn on automatically in June</h3>
				<p class="m-0 text-sm text-secondary">Pride Month, even when the toggle above is off.</p>
			</div>
			<Toggle id="galaxy-pride-june" v-model="style.prideAutoJune" />
		</div>
	</div>
</template>

<style scoped lang="scss">
.galaxy-swatch {
	width: 2rem;
	height: 2rem;
	border-radius: 999px;
	border: 2px solid transparent;
	cursor: pointer;
	padding: 0;
	box-shadow: 0 0 0 1px var(--color-divider, rgba(255, 255, 255, 0.15));
	transition: transform 0.1s ease;

	&:hover {
		transform: scale(1.1);
	}

	&.selected {
		border-color: var(--color-contrast);
	}
}

.galaxy-swatch-custom {
	position: relative;
	overflow: hidden;
	background: conic-gradient(red, yellow, lime, aqua, blue, magenta, red);

	input {
		position: absolute;
		inset: 0;
		opacity: 0;
		cursor: pointer;
	}
}

.galaxy-bg-preview {
	width: 6rem;
	height: 3.5rem;
	border-radius: var(--radius-md);
	background-size: cover;
	background-position: center;
	box-shadow: 0 0 0 1px var(--color-divider, rgba(255, 255, 255, 0.15));
}

.galaxy-select {
	background: var(--color-button-bg);
	color: var(--color-contrast);
	border: none;
	border-radius: var(--radius-md);
	padding: 0.5rem 0.75rem;
	font: inherit;
	min-width: 12rem;
}
</style>
