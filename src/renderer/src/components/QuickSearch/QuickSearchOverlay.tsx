import React, { useState, useCallback, useMemo, useEffect, useRef } from 'react'
import { TextInput } from '../Common/TextInput'
import { Icon } from '../Common/Icon'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { getIconSrc } from '@/utils/icons'
import type { ProgramItem, ProgramGroup } from '@shared/types'

interface SearchResult {
  item: ProgramItem
  group: ProgramGroup
}

export const QuickSearchOverlay: React.FC = () => {
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const closeQuickSearch = useUIStore((state) => state.closeQuickSearch)
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const inputRef = useRef<HTMLInputElement>(null)

  // Focus input on mount
  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  // Filter results based on query
  const results = useMemo<SearchResult[]>(() => {
    if (!query.trim()) return []

    const searchTerm = query.toLowerCase()
    const matches: SearchResult[] = []

    for (const group of groups) {
      for (const item of group.items) {
        if (item.name.toLowerCase().includes(searchTerm)) {
          matches.push({ item, group })
        }
      }
    }

    return matches
  }, [query, groups])

  const MAX_RESULTS = 10
  const displayedResults = results.slice(0, MAX_RESULTS)
  const hasMore = results.length > MAX_RESULTS

  // Reset selection when results change
  useEffect(() => {
    setSelectedIndex(0)
  }, [displayedResults.length])

  // Handle keyboard navigation
  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent) => {
      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault()
          setSelectedIndex((i) => Math.min(i + 1, displayedResults.length - 1))
          break
        case 'ArrowUp':
          event.preventDefault()
          setSelectedIndex((i) => Math.max(i - 1, 0))
          break
        case 'Enter':
          event.preventDefault()
          if (displayedResults[selectedIndex]) {
            launchItem(displayedResults[selectedIndex].item)
          }
          break
        case 'Escape':
          event.preventDefault()
          closeQuickSearch()
          break
      }
    },
    [displayedResults, selectedIndex, closeQuickSearch]
  )

  // Launch selected item
  const launchItem = useCallback(
    async (item: ProgramItem) => {
      try {
        const result = await window.electronAPI.program.launch(item)
        if (!result.success) {
          console.error('Failed to launch:', result.error)
        }
      } catch (error) {
        console.error('Failed to launch:', error)
      }

      closeQuickSearch()

      if (settings.minimizeOnUse) {
        try {
          window.electronAPI.window.minimize()
        } catch {
          // ignore
        }
      }
    },
    [closeQuickSearch, settings.minimizeOnUse]
  )

  // Handle item click
  const handleItemClick = useCallback(
    (item: ProgramItem) => {
      launchItem(item)
    },
    [launchItem]
  )

  // Handle overlay click to close
  const handleOverlayClick = useCallback(
    (event: React.MouseEvent) => {
      if (event.target === event.currentTarget) {
        closeQuickSearch()
      }
    },
    [closeQuickSearch]
  )

  return (
    <div className="win31-dialog-overlay" onClick={handleOverlayClick}>
      <div className="win31-dialog quick-search-dialog" style={{ width: 400 }}>
        <div className="win31-titlebar">
          <span className="win31-titlebar-text">Quick Search</span>
        </div>
        <div className="win31-dialog-content">
          <TextInput
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Type to search programs..."
            style={{ marginBottom: 8 }}
          />

          {displayedResults.length > 0 && (
            <div
              className="quick-search-results"
              style={{
                maxHeight: 300,
                overflowY: 'auto',
                border: '1px solid var(--bevel-dark)',
                borderColor: 'var(--bevel-dark) var(--bevel-light) var(--bevel-light) var(--bevel-dark)',
                background: 'var(--win31-white)'
              }}
            >
              {displayedResults.map((result, index) => (
                <div
                  key={`${result.group.id}-${result.item.id}`}
                  className={`quick-search-item ${index === selectedIndex ? 'selected' : ''}`}
                  onClick={() => handleItemClick(result.item)}
                  onMouseEnter={() => setSelectedIndex(index)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    padding: '4px 8px',
                    cursor: 'default',
                    backgroundColor: index === selectedIndex ? 'var(--selection-bg)' : 'transparent',
                    color: index === selectedIndex ? 'var(--selection-text)' : 'var(--text-primary)'
                  }}
                >
                  <Icon
                    src={getIconSrc(result.item.icon)}
                    size="small"
                  />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 'bold' }}>{result.item.name}</div>
                    <div style={{ fontSize: 10, opacity: 0.8 }}>{result.group.name}</div>
                  </div>
                </div>
              ))}
              {hasMore && (
                <div style={{ padding: '4px 8px', fontSize: 10, color: 'var(--text-disabled)', textAlign: 'center' }}>
                  {results.length - MAX_RESULTS} more result{results.length - MAX_RESULTS !== 1 ? 's' : ''} not shown
                </div>
              )}
            </div>
          )}

          {query && results.length === 0 && (
            <div style={{ padding: 16, textAlign: 'center', color: 'var(--text-disabled)' }}>
              No results found
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
