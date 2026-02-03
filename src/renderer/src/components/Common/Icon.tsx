import React from 'react'

interface IconProps {
  src: string
  alt?: string
  size?: 'small' | 'large'
  className?: string
}

export const Icon: React.FC<IconProps> = ({
  src,
  alt = '',
  size = 'large',
  className = ''
}) => {
  const sizeClass = size === 'small' ? 'icon-small' : 'icon'
  const sizeValue = size === 'small' ? 16 : 32

  // Handle both asset paths and data URLs
  const imgSrc = src.startsWith('data:') ? src : src

  return (
    <img
      src={imgSrc}
      alt={alt}
      width={sizeValue}
      height={sizeValue}
      className={`${sizeClass} ${className}`}
      style={{ imageRendering: 'pixelated' }}
      draggable={false}
    />
  )
}
