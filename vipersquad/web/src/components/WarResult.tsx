import React from 'react'
import { useSelector } from 'react-redux'
import { RootState } from '../store'

type WarResultData = {
    winner?: { id: number; name: string; score: number }
    loser?: { id: number; name: string; score: number }
    isDraw: boolean
    squad1?: { id: number; name: string; score: number }
    squad2?: { id: number; name: string; score: number }
    forfeit?: boolean
}

type Props = {
    data: WarResultData
    mySquadId: number | null
    onClose: () => void
}

export default function WarResult({ data, mySquadId, onClose }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)

    const isWinner = data.winner && data.winner.id === mySquadId
    const isDraw = data.isDraw

    const title = isDraw
        ? (locale.warDraw || 'Draw!')
        : isWinner
            ? (locale.warVictory || 'Victory!')
            : (locale.warDefeat || 'Defeat!')

    const titleColor = isDraw
        ? 'text-yellow-400'
        : isWinner
            ? 'text-success'
            : 'text-danger'

    return (
        <div className='absolute inset-0 z-50 flex-center bg-black/60 animate-opacity'>
            <div className='bg-menu-bg border border-menu-border rounded-lg p-6 w-[35vh] animate-popup'>
                <div className='flex flex-col items-center gap-4'>
                    <div className={`font-bold text-2xl uppercase tracking-wider ${titleColor}`}>
                        {title}
                    </div>
                    {isDraw ? (
                        <div className='flex flex-row items-center justify-center gap-6 w-full'>
                            <div className='flex flex-col items-center'>
                                <div className='text-white font-bold text-sm'>{data.squad1?.name}</div>
                                <div className='text-primary font-bold text-2xl'>{data.squad1?.score}</div>
                            </div>
                            <div className='text-white/[.3] font-bold text-lg'>vs</div>
                            <div className='flex flex-col items-center'>
                                <div className='text-white font-bold text-sm'>{data.squad2?.name}</div>
                                <div className='text-primary font-bold text-2xl'>{data.squad2?.score}</div>
                            </div>
                        </div>
                    ) : (
                        <div className='flex flex-row items-center justify-center gap-6 w-full'>
                            <div className='flex flex-col items-center'>
                                <div className='text-success font-bold text-sm'>{data.winner?.name}</div>
                                <div className='text-success font-bold text-2xl'>{data.winner?.score}</div>
                            </div>
                            <div className='text-white/[.3] font-bold text-lg'>vs</div>
                            <div className='flex flex-col items-center'>
                                <div className='text-danger font-bold text-sm'>{data.loser?.name}</div>
                                <div className='text-danger font-bold text-2xl'>{data.loser?.score}</div>
                            </div>
                        </div>
                    )}
                    <button
                        onClick={onClose}
                        className='w-full py-2 mt-2 bg-white/[.05] border border-white/[.1] text-white font-bold text-sm uppercase rounded hover:bg-white/[.1] duration-300'
                    >
                        {locale.close || 'Close'}
                    </button>
                </div>
            </div>
        </div>
    )
}
