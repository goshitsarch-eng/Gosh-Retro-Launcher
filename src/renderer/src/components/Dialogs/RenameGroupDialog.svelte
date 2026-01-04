<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import TextInput from '../Common/TextInput.svelte'
  import { uiStore, programStore } from '@/stores'

  let group = $derived(uiStore.dialogData.group)
  let name = $state(group?.name || '')

  // Sync name when group changes
  $effect(() => {
    if (group) {
      name = group.name
    }
  })

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    if (!group || !name.trim()) return
    programStore.updateGroup(group.id, { name: name.trim() })
    uiStore.closeDialog()
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

{#if group}
  <Dialog title="Rename Program Group" onClose={closeDialog} width={350}>
    {#snippet children()}
      <form onsubmit={handleSubmit}>
        <div class="win31-form-row">
          <label for="rename-group-name">Description:</label>
          <TextInput
            id="rename-group-name"
            bind:value={name}
            autofocus
          />
        </div>
        <div class="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!name.trim()}>
            {#snippet children()}OK{/snippet}
          </Button>
          <Button type="button" onclick={closeDialog}>
            {#snippet children()}Cancel{/snippet}
          </Button>
        </div>
      </form>
    {/snippet}
  </Dialog>
{/if}
