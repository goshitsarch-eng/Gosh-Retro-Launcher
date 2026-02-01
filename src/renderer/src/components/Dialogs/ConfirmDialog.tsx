import React, { useCallback } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { useUIStore } from '@/store/uiStore'
import { QUESTION_ICON } from '@/utils/icons'

export const ConfirmDialog: React.FC = () => {
  const { dialogData, closeDialog } = useUIStore()
  const confirmOptions = dialogData.confirmOptions

  const handleConfirm = useCallback(() => {
    confirmOptions?.onConfirm()
    closeDialog()
  }, [confirmOptions, closeDialog])

  const handleCancel = useCallback(() => {
    confirmOptions?.onCancel?.()
    closeDialog()
  }, [confirmOptions, closeDialog])

  if (!confirmOptions) return null

  return (
    <Dialog title={confirmOptions.title} onClose={handleCancel} width={350}>
      <div className="win31-confirm-content">
        <img
          src={QUESTION_ICON}
          alt="?"
          className="win31-confirm-icon"
          style={{ imageRendering: 'pixelated' }}
        />
        <div className="win31-confirm-message">{confirmOptions.message}</div>
      </div>

      <div className="win31-dialog-buttons">
        <Button onClick={handleConfirm} isDefault autoFocus>
          Yes
        </Button>
        <Button onClick={handleCancel}>No</Button>
      </div>
    </Dialog>
  )
}
