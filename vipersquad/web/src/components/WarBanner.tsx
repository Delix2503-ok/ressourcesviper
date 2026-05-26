import React from 'react'
import { useSelector } from 'react-redux'
import { RootState } from '../store'

type Props = {
    squad1: { id: number; name: string; score: number }
    squad2: { id: number; name: string; score: number }
    timeLeft: number
}

export default function WarBanner({ squad1, squad2, timeLeft }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [remaining, setRemaining] = React.useState(timeLeft)

    React.useEffect(() => {
        setRemaining(timeLeft)
    }, [timeLeft])

    React.useEffect(() => {
        const interval = setInterval(() => {
            setRemaining(prev => {
                if (prev <= 0) {
                    clearInterval(interval)
                    return 0
                }
                return prev - 1
            })
        }, 1000)
        return () => clearInterval(interval)
    }, [timeLeft])

    const formatTime = (seconds: number) => {
        const m = Math.floor(Math.max(0, seconds) / 60)
        const s = Math.max(0, seconds) % 60
        return `${m}:${s.toString().padStart(2, '0')}`
    }

    return (
        <div className='w-full bg-gradient-to-r from-danger/20 via-danger/10 to-danger/20 border-t border-b border-danger/30 py-2 px-4'>
            <div className='flex flex-row items-center justify-between'>
                <div className='flex flex-col items-center flex-1'>
                    <div className='text-white font-bold text-xs lg:text-sm truncate max-w-[10vh]'>{squad1.name}</div>
                    <div className='text-primary font-bold text-lg lg:text-2xl'>{squad1.score}</div>
                </div>
                <div className='flex flex-col items-center px-4'>
                    <div className='text-danger font-bold text-xs uppercase tracking-wider'>{locale.warInProgress || 'WAR'}</div>
                    <div className='text-white font-bold text-sm lg:text-lg'>{formatTime(remaining)}</div>
                </div>
                <div className='flex flex-col items-center flex-1'>
                    <div className='text-white font-bold text-xs lg:text-sm truncate max-w-[10vh]'>{squad2.name}</div>
                    <div className='text-primary font-bold text-lg lg:text-2xl'>{squad2.score}</div>
                </div>
            </div>
        </div>
    )
}
