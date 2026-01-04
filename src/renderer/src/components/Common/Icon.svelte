<script lang="ts">
  interface Props {
    src: string
    alt?: string
    size?: 'small' | 'large'
    class?: string
  }

  let { src, alt = '', size = 'large', class: className = '' }: Props = $props()

  let sizeClass = $derived(size === 'small' ? 'icon-small' : 'icon')
  let sizeValue = $derived(size === 'small' ? 16 : 32)
</script>

<img
  {src}
  {alt}
  width={sizeValue}
  height={sizeValue}
  class="{sizeClass} {className}"
  style="image-rendering: pixelated;"
  draggable="false"
/>
