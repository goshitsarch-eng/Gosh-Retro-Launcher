<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import Checkbox from '../Common/Checkbox.svelte'
  import { uiStore, programStore } from '@/stores'

  let settings = $derived(programStore.settings)

  let launchDelay = $state(settings.launchDelay)
  let autoArrange = $state(settings.autoArrange)
  let minimizeOnUse = $state(settings.minimizeOnUse)
  let saveSettingsOnExit = $state(settings.saveSettingsOnExit)
  let trayOnClose = $state(settings.trayOnClose)
  let groupChromeScale = $state(settings.groupChromeScale)
  let theme = $state(settings.theme)

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    programStore.updateSettings({
      launchDelay,
      autoArrange,
      minimizeOnUse,
      saveSettingsOnExit,
      trayOnClose,
      groupChromeScale,
      theme
    })
    uiStore.closeDialog()
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

<Dialog title="Settings" onClose={closeDialog} width={400}>
  {#snippet children()}
    <form onsubmit={handleSubmit}>
      <div class="win31-groupbox">
        <span class="win31-groupbox-label">General</span>

        <div style="margin-bottom: 8px;">
          <Checkbox
            label="Auto Arrange icons"
            bind:checked={autoArrange}
          />
        </div>

        <div style="margin-bottom: 8px;">
          <Checkbox
            label="Minimize on Use"
            bind:checked={minimizeOnUse}
          />
        </div>

        <div style="margin-bottom: 8px;">
          <Checkbox
            label="Save Settings on Exit"
            bind:checked={saveSettingsOnExit}
          />
        </div>

        <div>
          <Checkbox
            label="Minimize to Tray on Close"
            bind:checked={trayOnClose}
          />
        </div>
      </div>

      <div class="win31-groupbox">
        <span class="win31-groupbox-label">Appearance</span>

        <div style="margin-bottom: 8px;">
          <Checkbox
            label="Dark Mode"
            checked={theme === 'dark'}
            onchange={(e) => theme = e.currentTarget.checked ? 'dark' : 'light'}
          />
        </div>

        <div class="win31-slider-row">
          <label>Group Title Bar Size:</label>
          <input
            type="range"
            min={1}
            max={1.6}
            step={0.05}
            bind:value={groupChromeScale}
            style="flex: 1;"
          />
          <span class="value">{Math.round(groupChromeScale * 100)}%</span>
        </div>
      </div>

      <div class="win31-groupbox">
        <span class="win31-groupbox-label">Batch Launch</span>

        <div class="win31-slider-row">
          <label>Delay between launches:</label>
          <input
            type="range"
            min={100}
            max={5000}
            step={100}
            bind:value={launchDelay}
            style="flex: 1;"
          />
          <span class="value">{launchDelay}ms</span>
        </div>
      </div>

      <div class="win31-dialog-buttons">
        <Button type="submit" isDefault>
          {#snippet children()}OK{/snippet}
        </Button>
        <Button type="button" onclick={closeDialog}>
          {#snippet children()}Cancel{/snippet}
        </Button>
      </div>
    </form>
  {/snippet}
</Dialog>
