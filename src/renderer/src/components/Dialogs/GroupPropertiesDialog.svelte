<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import TextInput from '../Common/TextInput.svelte'
  import { uiStore, programStore, mdiStore } from '@/stores'
  import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'

  let group = $derived(uiStore.dialogData.group)

  let name = $state(group?.name || '')
  let icon = $state(group?.icon || 'folder')
  let showIconPicker = $state(uiStore.dialogData.showIconPicker ?? false)

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    if (!group || !name.trim()) return

    programStore.updateGroup(group.id, {
      name: name.trim(),
      icon
    })
    uiStore.closeDialog()
  }

  function handleDelete() {
    if (!group) return
    uiStore.openDialog('confirm', {
      confirmOptions: {
        title: 'Delete Group',
        message: `Are you sure you want to delete "${group.name}" and all its items?`,
        onConfirm: () => {
          mdiStore.closeWindow(group.id)
          programStore.deleteGroup(group.id)
        }
      }
    })
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

{#if group}
  <Dialog title="Program Group Properties" onClose={closeDialog} width={400}>
    {#snippet children()}
      <form onsubmit={handleSubmit}>
        <div class="win31-form-row">
          <label for="group-name">Description:</label>
          <TextInput
            id="group-name"
            bind:value={name}
            autofocus
          />
        </div>

        <div class="win31-form-row">
          <label>Icon:</label>
          <div style="display: flex; align-items: center; gap: 8px; flex: 1;">
            <img
              src={getIconSrc(icon)}
              alt="Icon"
              width="32"
              height="32"
              style="image-rendering: pixelated;"
            />
            <Button type="button" onclick={() => showIconPicker = !showIconPicker}>
              {#snippet children()}{showIconPicker ? 'Hide Icons' : 'Change Icon...'}{/snippet}
            </Button>
          </div>
        </div>

        {#if showIconPicker}
          <div
            style="
              display: grid;
              grid-template-columns: repeat(8, 1fr);
              gap: 4px;
              padding: 8px;
              background: var(--win31-white);
              border: 2px inset var(--bevel-dark);
              margin-bottom: 10px;
              max-height: 150px;
              overflow-y: auto;
            "
          >
            {#each BUILTIN_ICONS as iconOption (iconOption.id)}
              <div
                onclick={() => icon = iconOption.id}
                title={iconOption.name}
                role="button"
                tabindex="0"
                style="
                  width: 36px;
                  height: 36px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  cursor: pointer;
                  border: {icon === iconOption.id ? '2px solid var(--win31-blue)' : '2px solid transparent'};
                  background: {icon === iconOption.id ? 'var(--selection-bg)' : 'transparent'};
                "
              >
                <img
                  src={iconOption.icon}
                  alt={iconOption.name}
                  width="32"
                  height="32"
                  style="image-rendering: pixelated;"
                />
              </div>
            {/each}
          </div>
        {/if}

        <div class="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!name.trim()}>
            {#snippet children()}OK{/snippet}
          </Button>
          <Button type="button" onclick={closeDialog}>
            {#snippet children()}Cancel{/snippet}
          </Button>
          <Button type="button" onclick={handleDelete}>
            {#snippet children()}Delete{/snippet}
          </Button>
        </div>
      </form>
    {/snippet}
  </Dialog>
{/if}
