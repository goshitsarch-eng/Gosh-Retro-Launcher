import { describe, it, expect } from 'vitest'
import { tokenizeCommand, isValidExecPath } from '../launchHandlers'

describe('tokenizeCommand', () => {
  it('tokenizes a simple command', () => {
    expect(tokenizeCommand('ls -la')).toEqual(['ls', '-la'])
  })

  it('handles double-quoted arguments', () => {
    expect(tokenizeCommand('echo "hello world"')).toEqual(['echo', 'hello world'])
  })

  it('handles single-quoted arguments', () => {
    expect(tokenizeCommand("echo 'hello world'")).toEqual(['echo', 'hello world'])
  })

  it('handles escaped characters', () => {
    expect(tokenizeCommand('echo hello\\ world')).toEqual(['echo', 'hello world'])
  })

  it('returns empty array for empty string', () => {
    expect(tokenizeCommand('')).toEqual([])
  })

  it('handles mixed quotes', () => {
    expect(tokenizeCommand(`cmd 'a b' "c d"`)).toEqual(['cmd', 'a b', 'c d'])
  })

  it('collapses multiple spaces', () => {
    expect(tokenizeCommand('a   b')).toEqual(['a', 'b'])
  })
})

describe('isValidExecPath', () => {
  it('accepts a valid path', () => {
    expect(isValidExecPath('/usr/bin/firefox')).toBe(true)
  })

  it('rejects empty string', () => {
    expect(isValidExecPath('')).toBe(false)
  })

  it('rejects semicolon (shell injection)', () => {
    expect(isValidExecPath('cmd; rm -rf /')).toBe(false)
  })

  it('rejects ampersand', () => {
    expect(isValidExecPath('cmd & echo pwned')).toBe(false)
  })

  it('rejects pipe', () => {
    expect(isValidExecPath('cmd | cat /etc/passwd')).toBe(false)
  })

  it('rejects backtick', () => {
    expect(isValidExecPath('cmd `whoami`')).toBe(false)
  })

  it('rejects dollar sign', () => {
    expect(isValidExecPath('cmd $HOME')).toBe(false)
  })

  it('rejects parentheses', () => {
    expect(isValidExecPath('cmd (subshell)')).toBe(false)
    expect(isValidExecPath('cmd )')).toBe(false)
  })

  it('rejects curly braces', () => {
    expect(isValidExecPath('cmd {a,b}')).toBe(false)
    expect(isValidExecPath('cmd }')).toBe(false)
  })

  it('accepts a path with spaces', () => {
    expect(isValidExecPath('/path/to/my app')).toBe(true)
  })
})
