import React from 'react'
import MenuItem from './MenuItem'
import LeaderboardEntry from '../types/leaderboard'
import cx from 'classnames'

type Props = {
    entry: LeaderboardEntry
    rank: number
    first?: boolean
}

export default function LeaderboardItem({
    entry,
    rank,
    first,
}: Props) {
    const rankColors: Record<number, string> = {
        1: 'text-yellow-400',
        2: 'text-gray-300',
        3: 'text-amber-600',
    }

    return (
        <MenuItem first={first}>
            <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                <div className='flex flex-row items-center gap-3 flex-[4]'>
                    <div className={cx('font-bold text-lg lg:text-2xl w-8 text-center', rankColors[rank] || 'text-white/[.3]')}>
                        {rank}
                    </div>
                    <div className='size-[5vh] rounded-full border-2 border-primary overflow-hidden'>
                        <img src={entry.image} alt={entry.name} className='w-full h-full object-cover' />
                    </div>
                    <div className='text-white font-bold text-sm lg:text-lg truncate max-w-[12vh]'>
                        {entry.name}
                    </div>
                </div>
                <div className='flex flex-row items-center flex-[3] justify-end gap-6'>
                    <div className='text-center'>
                        <div className='text-success font-bold text-sm lg:text-lg'>{entry.kills}</div>
                    </div>
                    <div className='text-center'>
                        <div className='text-danger font-bold text-sm lg:text-lg'>{entry.deaths}</div>
                    </div>
                    <div className='text-center min-w-[4vh]'>
                        <div className='text-white/[.6] font-bold text-sm lg:text-lg'>{entry.kd}</div>
                    </div>
                </div>
            </div>
        </MenuItem>
    )
}
