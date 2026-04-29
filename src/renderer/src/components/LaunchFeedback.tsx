import React from 'react'
import { useUIStore } from '@/store/uiStore'

export const LaunchFeedback: React.FC = () => {
  const feedback = useUIStore((state) => state.launchFeedback)

  if (!feedback.visible) return null

  const progress =
    feedback.totalGroups > 0
      ? Math.min(100, Math.round((feedback.completedGroups / feedback.totalGroups) * 100))
      : 0
  const isLaunching = feedback.status === 'launching'
  const statusText =
    feedback.status === 'complete'
      ? `Launched ${feedback.totalItems} item${feedback.totalItems === 1 ? '' : 's'}`
      : feedback.status === 'error'
        ? `${feedback.failures} launch${feedback.failures === 1 ? '' : 'es'} failed`
        : feedback.currentGroup !== null
          ? `Launching Group ${feedback.currentGroup}`
          : 'Preparing launch groups'

  return (
    <div className={`launch-feedback ${feedback.status}`} role="status" aria-live="polite">
      <div className="launch-feedback-icon" aria-hidden="true">
        {isLaunching ? '>>' : feedback.status === 'error' ? '!' : 'OK'}
      </div>
      <div className="launch-feedback-body">
        <div className="launch-feedback-title">{statusText}</div>
        <div className="launch-feedback-detail">
          {feedback.completedGroups} of {feedback.totalGroups} groups
        </div>
        <div className="launch-feedback-meter" aria-hidden="true">
          <div className="launch-feedback-meter-fill" style={{ width: `${progress}%` }} />
        </div>
      </div>
    </div>
  )
}
