export const LAUNCH_GROUP_OPTIONS = Array.from({ length: 9 }, (_, index) => index)

export function formatLaunchGroup(value: number): string {
  if (value <= 0) {
    return 'None'
  }
  return `Group ${value}`
}
