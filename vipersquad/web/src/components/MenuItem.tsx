import React from 'react'
import cx from 'classnames'

type Props = {
    children?: React.ReactNode
    first?: boolean
}

export default function MenuItem({
    children,
    first,
}: Props) {
    return (
        <div className={cx('w-full h-[9.1vh] relative bg-gradient-to-r from-menu-item from-0% via-menu-darker via-90% to-primary-opacity border-r-[0.5556vh] border-primary border-b border-b-white/[.07]', {
            'border-t border-t-white/[.03]': first,
        })}>
            {
                children
            }
        </div>
    )
}