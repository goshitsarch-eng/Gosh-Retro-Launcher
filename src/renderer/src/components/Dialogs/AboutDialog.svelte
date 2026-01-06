<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import { uiStore } from '@/stores'
  import { APP_ICON } from '@/utils/icons'

  let platform = $state('')

  $effect(() => {
    window.electronAPI.system.getPlatform().then((p) => {
      const platformNames: Record<string, string> = {
        win32: 'Windows',
        darwin: 'macOS',
        linux: 'Linux'
      }
      platform = platformNames[p] || p
    })
  })

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

<Dialog title="About Gosh Retro Launcher" onClose={closeDialog} width={350}>
  {#snippet children()}
    <div class="win31-about-content">
      <img
        src={APP_ICON}
        alt="Gosh Retro Launcher"
        class="win31-about-icon"
        style="width: 48px; height: 48px; image-rendering: pixelated;"
      />

      <div class="win31-about-title">Gosh Retro Launcher</div>
      <div class="win31-about-version">Version 2.0.1</div>

      <hr class="win31-about-separator" />

      <div class="win31-about-info">
        A Windows 3.1 Program Manager clone
        <br />
        built with Tauri and Svelte.
      </div>

      <div class="win31-about-info" style="margin-top: 8px;">
        Running on {platform}
      </div>

      <hr class="win31-about-separator" />

      <div class="win31-about-info" style="font-size: 10px;">
        © 2024 Goshitsarch. Made with nostalgia.
      </div>
    </div>

    <div class="win31-dialog-buttons">
      <Button onclick={closeDialog} isDefault autofocus>
        {#snippet children()}OK{/snippet}
      </Button>
    </div>
  {/snippet}
</Dialog>
