<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import TextInput from '../Common/TextInput.svelte'
  import { uiStore, programStore } from '@/stores'

  let name = $state('')

  let openItemAfterCreate = $derived(uiStore.dialogData.openItemAfterCreate)
  let openUrlAfterCreate = $derived(uiStore.dialogData.openUrlAfterCreate)

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    if (name.trim()) {
      const newGroupId = programStore.addGroup(name.trim())
      if (openItemAfterCreate) {
        uiStore.openDialog('newItem', { groupId: newGroupId })
      } else if (openUrlAfterCreate) {
        uiStore.openDialog('newUrl', { groupId: newGroupId })
      } else {
        uiStore.closeDialog()
      }
    }
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

<Dialog title="New Program Group" onClose={closeDialog} width={350}>
  {#snippet children()}
    <form onsubmit={handleSubmit}>
      {#if openItemAfterCreate}
        <div style="margin-bottom: 8px; font-size: 12px;">
          Create a group to add your new program item.
        </div>
      {/if}
      {#if openUrlAfterCreate}
        <div style="margin-bottom: 8px; font-size: 12px;">
          Create a group to add your URL.
        </div>
      {/if}
      <div class="win31-form-row">
        <label for="group-name">Description:</label>
        <TextInput
          id="group-name"
          bind:value={name}
          autofocus
          placeholder="Enter group name"
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
