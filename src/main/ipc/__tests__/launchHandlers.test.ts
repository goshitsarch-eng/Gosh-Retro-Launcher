import { describe, it, expect } from 'vitest'
import { tokenizeCommand, isValidExecPath, parseEnvironment } from '../launchHandlers'

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

  it('preserves Windows path separators in arguments', () => {
    expect(tokenizeCommand('C:\\Temp\\input.txt "C:\\Long Path\\output.txt"')).toEqual([
      'C:\\Temp\\input.txt', 'C:\\Long Path\\output.txt'
    ])
  })

  it('collapses multiple spaces', () => {
    expect(tokenizeCommand('a   b')).toEqual(['a', 'b'])
  })
})

describe('parseEnvironment', () => {
  it('merges valid KEY=VALUE lines and ignores comments or malformed lines', () => {
    const environment = parseEnvironment('ALPHA=one\n# comment\nINVALID\nBETA=two=parts')
    expect(environment.ALPHA).toBe('one')
    expect(environment.BETA).toBe('two=parts')
    expect(environment.INVALID).toBeUndefined()
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
