import React from 'react'
import cx from 'classnames'

type Props = {
    children?: React.ReactNode
}

export default function MenuTitle({
    children,
}: Props) {
    return (
        <div className='w-full min-h-[9.25vh] relative bg-gradient-to-r from-[#ffffff]/[0] from-0% via-[#ffffff]/[.03] via-50% to-[#ffffff]/[0] border-t border-b border-white/[.15]'>
            {
                children
            }
        </div>
    )
}