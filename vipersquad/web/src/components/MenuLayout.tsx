import React from 'react'
import { useNuiEvent } from '../hooks/useNuiEvent'
import { useSelector } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'
import cx from 'classnames'

type Props = {
    props: any
    children?: React.ReactNode
}

export default function MenuLayout({
    props,
    children,
}: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const { type } = props

    return (
        <div className='overflow-y-auto flex flex-col h-full gap-5'>
            <div className='mt-4 flex flex-row justify-between items-center px-6'>
                <div className='flex flex-row items-center gap-2'>
                    <div className={cx('flex flex-row items-center', {
                        "border-b border-primary": type === 'squads' || type === 'members' || type === 'invites' || type === 'leaderboard' || type === 'warTargets',
                    })}>
                        <div className='flex-center clipped bg-primary py-1 px-4 pr-12 font-bold uppercase italic text-primary-content text-xs lg:text-xl'>
                            {locale[type]}
                        </div>
                        {
                            props?.startChild
                        }
                    </div>
                </div>
                {
                    props?.endChild
                }
            </div>
            {
                children
            }
        </div>
    )
}