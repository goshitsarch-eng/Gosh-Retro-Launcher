export type Win31Command =
  | 'new'
  | 'open'
  | 'move'
  | 'copy'
  | 'delete'
  | 'properties'
  | 'run'
  | 'exit'
  | 'auto-arrange'
  | 'minimize-on-use'
  | 'save-settings'
  | 'cascade'
  | 'tile'
  | 'arrange-icons'
  | 'help-contents'
  | 'help-search'
  | 'help-using'
  | 'about'
  | `group:${string}`
  | 'outer-restore'
  | 'outer-move'
  | 'outer-size'
  | 'outer-minimize'
  | 'outer-maximize'
  | 'outer-close'
  | 'child-restore'
  | 'child-move'
  | 'child-size'
  | 'child-minimize'
  | 'child-maximize'
  | 'child-close'

export interface Win31CommandState {
  disabled?: boolean
  checked?: boolean
}
