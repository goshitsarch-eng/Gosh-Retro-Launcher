import { useEffect, useMemo, useRef, useState, type JSX } from 'react'
import { useProgramStore } from '@/store/programStore'
import { findPrograms, type ProgramSearchResult, type Win95FindFilters } from '@/utils/programSearch'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { Win95BitmapText } from './bitmapText'
import { Win95Button, Win95Checkbox, Win95Select, Win95TextInput } from './Win95Primitives'
import { Win95Scrollbar } from './Win95Scrollbar'
import { clampWin95Scroll } from './scrollbarState'
import { selectWin95Item, type Win95SelectionState } from './selectionState'

export function Win95FindView({ onResultCount, onSelectionChange, command }: {
  onResultCount: (count: number) => void
  onSelectionChange?: (id: string | null) => void
  command?: { type: 'open' | 'select-all'; nonce: number } | null
}): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const minimizeOnUse = useProgramStore((state) => state.settings.minimizeOnUse)
  const { scale } = useWin95Scale()
  const timerRef = useRef<number | null>(null)
  const namedRef = useRef<HTMLInputElement>(null)
  const [tab, setTab] = useState<'name' | 'date' | 'advanced'>('name')
  const [named, setNamed] = useState('*')
  const [groupId, setGroupId] = useState('')
  const [includeSubgroups, setIncludeSubgroups] = useState(true)
  const [type, setType] = useState<Win95FindFilters['type']>('all')
  const [containing, setContaining] = useState('')
  const [path, setPath] = useState('')
  const [running, setRunning] = useState(false)
  const [searched, setSearched] = useState(false)
  const [results, setResults] = useState<ProgramSearchResult[]>([])
  const [selection, setSelection] = useState<Win95SelectionState>({ selected: [], focused: null, anchor: null })
  const [scrollY, setScrollY] = useState(0)
  const resultHeight = 53
  const rowHeight = 19
  const contentHeight = Math.max(resultHeight, results.length * rowHeight)

  useEffect(() => { namedRef.current?.focus() }, [])
  useEffect(() => () => { if (timerRef.current) window.clearTimeout(timerRef.current) }, [])
  useEffect(() => {
    onResultCount(results.length)
    const focused = selection.focused ?? selection.selected[0] ?? null
    onSelectionChange?.(focused)
  }, [onResultCount, onSelectionChange, results.length, selection.focused, selection.selected])

  const filters = useMemo<Win95FindFilters>(() => ({
    named,
    ...(groupId ? { groupId } : {}),
    includeSubgroups,
    type,
    containing,
    path
  }), [containing, groupId, includeSubgroups, named, path, type])

  const stop = (): void => {
    if (timerRef.current) window.clearTimeout(timerRef.current)
    timerRef.current = null
    setRunning(false)
  }
  const findNow = (): void => {
    stop(); setRunning(true); setSearched(true); setSelection({ selected: [], focused: null, anchor: null }); setScrollY(0)
    timerRef.current = window.setTimeout(() => {
      const next = findPrograms(groups, filters)
      setResults(next)
      setRunning(false)
      timerRef.current = null
    }, 180)
  }
  const newSearch = (): void => {
    stop(); setNamed('*'); setGroupId(''); setIncludeSubgroups(true); setType('all'); setContaining(''); setPath('')
    setResults([]); setSearched(false); setSelection({ selected: [], focused: null, anchor: null }); setScrollY(0); setTab('name')
    window.setTimeout(() => namedRef.current?.focus(), 0)
  }
  const launch = async (result: ProgramSearchResult): Promise<void> => {
    const launched = await window.electronAPI.program.launch(result.item)
    if (launched.success && minimizeOnUse) void window.electronAPI.window.minimize()
  }
  const resultIds = results.map((result) => `${result.group.id}:${result.item.id}`)
  const focusedIndex = Math.max(0, resultIds.indexOf(selection.focused ?? ''))
  useEffect(() => {
    if (command?.type === 'select-all') setSelection({ selected: resultIds, focused: resultIds[0] ?? null, anchor: resultIds[0] ?? null })
    else if (command?.type === 'open' && results[focusedIndex]) void launch(results[focusedIndex])
  }, [command?.nonce])

  return <div className="win95-find-view" onKeyDown={(event) => {
    if (event.key === 'Enter' && event.target === namedRef.current) { event.preventDefault(); findNow(); return }
    if (!results.length || !(event.target as HTMLElement).closest('.win95-find-result-area')) return
    let index = focusedIndex
    if (event.key === 'ArrowDown') index = Math.min(results.length - 1, index + 1)
    else if (event.key === 'ArrowUp') index = Math.max(0, index - 1)
    else if (event.key === 'Home') index = 0
    else if (event.key === 'End') index = results.length - 1
    else if (event.key === 'PageDown') index = Math.min(results.length - 1, index + 3)
    else if (event.key === 'PageUp') index = Math.max(0, index - 3)
    else if (event.key === 'Enter') { event.preventDefault(); void launch(results[focusedIndex]); return }
    else if (event.ctrlKey && event.key.toLowerCase() === 'a') { event.preventDefault(); setSelection({ selected: resultIds, focused: resultIds[0], anchor: resultIds[0] }); return }
    else return
    event.preventDefault()
    const id = resultIds[index]
    setSelection((current) => selectWin95Item(current, id, resultIds, { shift: event.shiftKey, ctrl: event.ctrlKey }))
    const y = index * rowHeight
    setScrollY((current) => y < current ? y : y + rowHeight > current + resultHeight ? y + rowHeight - resultHeight : current)
  }}>
    <div className="win95-find-tabs" role="tablist">
      <button type="button" role="tab" aria-selected={tab === 'name'} className={tab === 'name' ? 'selected' : ''} onClick={() => setTab('name')}><Win95BitmapText text="&Name && Location" /></button>
      <button type="button" role="tab" aria-selected={tab === 'date'} className={tab === 'date' ? 'selected' : ''} onClick={() => setTab('date')}><Win95BitmapText text="&Date Modified" /></button>
      <button type="button" role="tab" aria-selected={tab === 'advanced'} className={tab === 'advanced' ? 'selected' : ''} onClick={() => setTab('advanced')}><Win95BitmapText text="&Advanced" /></button>
    </div>
    <div className="win95-find-criteria">
      <div className="win95-find-page">
        {tab === 'name' && <>
          <label><Win95BitmapText text="&Named:" /><Win95TextInput ref={namedRef} value={named} onChange={(event) => setNamed(event.target.value)} /></label>
          <label><Win95BitmapText text="&Look in:" /><Win95Select value={groupId} onChange={(event) => setGroupId(event.target.value)}><option value="">All launcher groups</option>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</Win95Select></label>
          <Win95Checkbox label="&Include subgroups" checked={includeSubgroups} onChange={(event) => setIncludeSubgroups(event.target.checked)} />
        </>}
        {tab === 'date' && <div className="win95-find-date-disabled" aria-disabled="true">
          <Win95BitmapText text="Date criteria are unavailable because launcher items do not store modified dates." disabled wrap maxWidth={265} />
          <Win95Checkbox label="&All files" checked disabled />
        </div>}
        {tab === 'advanced' && <>
          <label><Win95BitmapText text="Of &type:" /><Win95Select value={type} onChange={(event) => setType(event.target.value as Win95FindFilters['type'])}><option value="all">All launcher items</option><option value="application">Application</option><option value="internet">Internet Shortcut</option></Win95Select></label>
          <label><Win95BitmapText text="&Containing text:" /><Win95TextInput value={containing} onChange={(event) => setContaining(event.target.value)} /></label>
          <label><Win95BitmapText text="&Path contains:" /><Win95TextInput value={path} onChange={(event) => setPath(event.target.value)} /></label>
        </>}
      </div>
      <div className="win95-find-actions">
        <Win95Button label="&Find Now" defaultButton={!running} disabled={running} onClick={findNow} />
        <Win95Button label="&Stop" disabled={!running} onClick={stop} />
        <Win95Button label="&New Search" onClick={newSearch} />
      </div>
    </div>
    <div className="win95-find-result-area" tabIndex={0} role="listbox" aria-multiselectable="true">
      <div className="win95-find-result-header"><span><Win95BitmapText text="Name" /></span><span><Win95BitmapText text="In Folder" /></span></div>
      <div className="win95-find-result-rows" style={{ height: resultHeight }}>
        {results.map((result, index) => {
          const id = resultIds[index]
          const selected = selection.selected.includes(id)
          return <button type="button" key={id} role="option" aria-selected={selected} className={selected ? 'selected' : ''}
            style={{ top: index * rowHeight - scrollY }}
            onPointerDown={(event) => setSelection((current) => selectWin95Item(current, id, resultIds, { ctrl: event.ctrlKey, shift: event.shiftKey }))}
            onDoubleClick={() => void launch(result)}>
            <span><img src={getWin95IconSrc(result.item.icon, 'small', scale)} alt="" /><Win95BitmapText text={result.item.name} color={selected ? '#ffffff' : '#000000'} /></span>
            <span><Win95BitmapText text={result.group.name} color={selected ? '#ffffff' : '#000000'} /></span>
          </button>
        })}
        {!running && searched && !results.length && <div className="win95-find-empty"><Win95BitmapText text="No files found." /></div>}
        {running && <div className="win95-find-empty"><Win95BitmapText text="Searching..." /></div>}
      </div>
      {contentHeight > resultHeight && <Win95Scrollbar orientation="vertical" value={scrollY} viewportSize={resultHeight} contentSize={contentHeight} length={resultHeight + 18}
        onChange={(y) => setScrollY(clampWin95Scroll(y, contentHeight, resultHeight))} lineSize={rowHeight} />}
    </div>
  </div>
}
