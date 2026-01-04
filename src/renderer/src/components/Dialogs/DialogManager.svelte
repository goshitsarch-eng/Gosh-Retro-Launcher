<script lang="ts">
  import { uiStore } from '@/stores'
  import NewGroupDialog from './NewGroupDialog.svelte'
  import RenameGroupDialog from './RenameGroupDialog.svelte'
  import GroupPropertiesDialog from './GroupPropertiesDialog.svelte'
  import ItemPropertiesDialog from './ItemPropertiesDialog.svelte'
  import NewUrlDialog from './NewUrlDialog.svelte'
  import SettingsDialog from './SettingsDialog.svelte'
  import AboutDialog from './AboutDialog.svelte'
  import ConfirmDialog from './ConfirmDialog.svelte'

  let activeDialog = $derived(uiStore.activeDialog)
</script>

{#if activeDialog === 'newGroup'}
  <NewGroupDialog />
{:else if activeDialog === 'renameGroup'}
  <RenameGroupDialog />
{:else if activeDialog === 'groupProperties'}
  <GroupPropertiesDialog />
{:else if activeDialog === 'newItem' || activeDialog === 'itemProperties'}
  <ItemPropertiesDialog />
{:else if activeDialog === 'newUrl'}
  <NewUrlDialog />
{:else if activeDialog === 'settings'}
  <SettingsDialog />
{:else if activeDialog === 'about'}
  <AboutDialog />
{:else if activeDialog === 'confirm'}
  <ConfirmDialog />
{/if}
