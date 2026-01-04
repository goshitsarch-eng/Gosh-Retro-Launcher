<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  interface Props extends Omit<HTMLInputAttributes, 'type' | 'checked'> {
    label: string
    checked?: boolean
    ref?: HTMLInputElement
  }

  let { label, checked = $bindable(false), class: className = '', id, ref = $bindable(), ...rest }: Props = $props()

  let inputId = $derived(id || `checkbox-${label.replace(/\s+/g, '-').toLowerCase()}`)
</script>

<label for={inputId} class="win31-checkbox {className}">
  <input bind:this={ref} bind:checked type="checkbox" id={inputId} {...rest} />
  <span class="checkmark"></span>
  <span class="label">{label}</span>
</label>
