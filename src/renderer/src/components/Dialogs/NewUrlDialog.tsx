import React, { useState, useCallback, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'

function normalizeUrl(raw: string): string {
  const trimmed = raw.trim()
  if (!trimmed) return trimmed

  const hasScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed)
  return hasScheme ? trimmed : `https://${trimmed}`
}

function deriveName(url: string): string {
  try {
    const parsed = new URL(url)
    if (parsed.hostname) {
      return parsed.hostname
    }
    if (parsed.protocol === 'mailto:' && parsed.pathname) {
      return parsed.pathname
    }
    return parsed.href
  } catch {
    return url
  }
}

export const NewUrlDialog: React.FC = () => {
  const { dialogData, closeDialog } = useUIStore()
  const groups = useProgramStore((state) => state.groups)
  const addItem = useProgramStore((state) => state.addItem)

  const resolvedGroupId = dialogData.groupId || groups[0]?.id || ''
  const [selectedGroupId, setSelectedGroupId] = useState(resolvedGroupId)
  const [url, setUrl] = useState('')
  const [name, setName] = useState('')
  const [launchGroup, setLaunchGroup] = useState(0)

  useEffect(() => {
    if (!selectedGroupId && resolvedGroupId) {
      setSelectedGroupId(resolvedGroupId)
    }
  }, [resolvedGroupId, selectedGroupId])

  const isValidUrl = useCallback((raw: string): boolean => {
    try {
      new URL(normalizeUrl(raw))
      return true
    } catch {
      return false
    }
  }, [])

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (!url.trim() || !selectedGroupId) return

      const normalizedUrl = normalizeUrl(url)
      if (!isValidUrl(url)) return
      const finalName = name.trim() || deriveName(normalizedUrl)

      addItem(selectedGroupId, {
        name: finalName,
        path: normalizedUrl,
        icon: 'web',
        workingDir: '',
        launchGroup
      })

      closeDialog()
    },
    [url, name, selectedGroupId, launchGroup, addItem, closeDialog, isValidUrl]
  )

  return (
    <Dialog title="Add URL" onClose={closeDialog} width={420}>
      <form onSubmit={handleSubmit}>
        {groups.length > 1 && (
          <div className="win31-form-row">
            <label htmlFor="url-group">Program Group:</label>
            <select
              id="url-group"
              className="win31-input"
              value={selectedGroupId}
              onChange={(e) => setSelectedGroupId(e.target.value)}
            >
              {groups.map((group) => (
                <option key={group.id} value={group.id}>
                  {group.name}
                </option>
              ))}
            </select>
          </div>
        )}

        <div className="win31-form-row">
          <label htmlFor="url-input">URL:</label>
          <TextInput
            id="url-input"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            autoFocus
            placeholder="https://example.com"
          />
        </div>

        <div className="win31-form-row">
          <label htmlFor="url-name">Name:</label>
          <TextInput
            id="url-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Optional (defaults to host)"
          />
        </div>

        <div className="win31-form-row">
          <label htmlFor="url-launch-group">Launch Group:</label>
          <select
            id="url-launch-group"
            className="win31-input"
            value={launchGroup}
            onChange={(e) => setLaunchGroup(Number(e.target.value))}
            style={{ width: 150 }}
          >
            {LAUNCH_GROUP_OPTIONS.map((value) => (
              <option key={value} value={value}>
                {formatLaunchGroup(value)}
              </option>
            ))}
          </select>
        </div>

        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!url.trim() || !selectedGroupId || !isValidUrl(url)}>
            OK
          </Button>
          <Button type="button" onClick={closeDialog}>
            Cancel
          </Button>
        </div>
      </form>
    </Dialog>
  )
}
