import React from 'react'
import { useUIStore } from '@/store/uiStore'
import { NewGroupDialog } from './NewGroupDialog'
import { RenameGroupDialog } from './RenameGroupDialog'
import { GroupPropertiesDialog } from './GroupPropertiesDialog'
import { ItemPropertiesDialog } from './ItemPropertiesDialog'
import { NewUrlDialog } from './NewUrlDialog'
import { SettingsDialog } from './SettingsDialog'
import { AboutDialog } from './AboutDialog'
import { ConfirmDialog } from './ConfirmDialog'
import { WelcomeDialog } from './WelcomeDialog'

export const DialogManager: React.FC = () => {
  const activeDialog = useUIStore((state) => state.activeDialog)

  switch (activeDialog) {
    case 'newGroup':
      return <NewGroupDialog />
    case 'renameGroup':
      return <RenameGroupDialog />
    case 'groupProperties':
      return <GroupPropertiesDialog />
    case 'newItem':
    case 'itemProperties':
      return <ItemPropertiesDialog />
    case 'newUrl':
      return <NewUrlDialog />
    case 'settings':
      return <SettingsDialog />
    case 'about':
      return <AboutDialog />
    case 'confirm':
      return <ConfirmDialog />
    case 'welcome':
      return <WelcomeDialog />
    default:
      return null
  }
}
