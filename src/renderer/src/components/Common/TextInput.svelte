<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements'

  interface Props extends Omit<HTMLInputAttributes, 'value'> {
    value?: string
    ref?: HTMLInputElement
  }

  let { class: className = '', value = $bindable(''), ref = $bindable(), ...rest }: Props = $props()
</script>

<input
  bind:this={ref}
  bind:value
  type="text"
  class="win31-input {className}"
  {...rest}
/>
