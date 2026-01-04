<script lang="ts">
  import type { Snippet } from 'svelte'
  import type { HTMLButtonAttributes } from 'svelte/elements'

  interface Props extends HTMLButtonAttributes {
    isDefault?: boolean
    small?: boolean
    children: Snippet
    ref?: HTMLButtonElement
  }

  let {
    isDefault = false,
    small = false,
    class: className = '',
    children,
    ref = $bindable(),
    ...rest
  }: Props = $props()

  let classes = $derived(
    [
      small ? 'win31-control-button' : 'win31-button',
      isDefault ? 'default' : '',
      className
    ].filter(Boolean).join(' ')
  )
</script>

<button bind:this={ref} class={classes} {...rest}>
  {@render children()}
</button>
