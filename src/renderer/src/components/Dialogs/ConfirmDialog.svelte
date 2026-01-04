<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import { uiStore } from '@/stores'
  import { QUESTION_ICON } from '@/utils/icons'

  let confirmOptions = $derived(uiStore.dialogData.confirmOptions)

  function handleConfirm() {
    confirmOptions?.onConfirm?.()
    uiStore.closeDialog()
  }

  function handleCancel() {
    confirmOptions?.onCancel?.()
    uiStore.closeDialog()
  }
</script>

{#if confirmOptions}
  <Dialog title={confirmOptions.title} onClose={handleCancel} width={350}>
    {#snippet children()}
      <div class="win31-confirm-content">
        <img
          src={QUESTION_ICON}
          alt="?"
          class="win31-confirm-icon"
          style="image-rendering: pixelated;"
        />
        <div class="win31-confirm-message">{confirmOptions.message}</div>
      </div>

      <div class="win31-dialog-buttons">
        <Button onclick={handleConfirm} isDefault autofocus>
          {#snippet children()}Yes{/snippet}
        </Button>
        <Button onclick={handleCancel}>
          {#snippet children()}No{/snippet}
        </Button>
      </div>
    {/snippet}
  </Dialog>
{/if}
