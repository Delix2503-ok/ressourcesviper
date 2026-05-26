import React, { useState, useEffect } from 'react'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { setMyBet } from '../slices/globalSlice'
import { fetchNui } from '../utils/fetchNui'

type Props = {
    squad1: { id: number; name: string; score: number }
    squad2: { id: number; name: string; score: number }
    betWaitTime: number
    minBet: number
    maxBet: number
    myBet?: number
    onClose: () => void
}

export default function WarBetting({ squad1, squad2, betWaitTime, minBet, maxBet, myBet, onClose }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const dispatch = useDispatch()
    const [amount, setAmount] = useState('')
    const [remaining, setRemaining] = useState(betWaitTime)
    const [placing, setPlacing] = useState(false)
    const [error, setError] = useState('')

    useEffect(() => {
        const interval = setInterval(() => {
            setRemaining(prev => {
                if (prev <= 1) {
                    clearInterval(interval)
                    return 0
                }
                return prev - 1
            })
        }, 1000)
        return () => clearInterval(interval)
    }, [])

    const handlePlaceBet = () => {
        const betAmount = parseInt(amount)
        if (isNaN(betAmount)) return

        if (betAmount < minBet) {
            setError((locale.betMin || 'Minimum bet: $%s').replace('%s', minBet.toString()))
            return
        }
        if (betAmount > maxBet) {
            setError((locale.betMax || 'Maximum bet: $%s').replace('%s', maxBet.toString()))
            return
        }

        setPlacing(true)
        setError('')
        fetchNui('placeBet', betAmount).then((result) => {
            if (result) {
                dispatch(setMyBet(betAmount))
            } else {
                setError(locale.insufficientFunds || 'Not enough money')
            }
            setPlacing(false)
        }).catch(() => {
            setPlacing(false)
        })
    }

    return (
        <div className='absolute inset-0 z-50 flex-center bg-black/60 animate-opacity'>
            <div className='bg-menu-bg border border-menu-border rounded-lg p-6 w-[35vh] animate-popup'>
                <div className='flex flex-col items-center gap-4'>
                    <div className='text-primary font-bold text-lg uppercase tracking-wider'>
                        {locale.warBettingPhase || 'Place Your Bets!'}
                    </div>

                    {/* Squads */}
                    <div className='flex flex-row items-center justify-center gap-6 w-full'>
                        <div className='flex flex-col items-center'>
                            <div className='text-white font-bold text-sm'>{squad1.name}</div>
                        </div>
                        <div className='text-white/30 font-bold text-lg'>vs</div>
                        <div className='flex flex-col items-center'>
                            <div className='text-white font-bold text-sm'>{squad2.name}</div>
                        </div>
                    </div>

                    {/* Countdown */}
                    <div className='text-danger font-bold text-2xl'>
                        {remaining}s
                    </div>

                    {/* Bet Input or Placed */}
                    {myBet ? (
                        <div className='flex flex-col items-center gap-2'>
                            <div className='text-success font-bold text-sm uppercase'>
                                {locale.betPlaced || 'Bet Placed!'}
                            </div>
                            <div className='text-white font-bold text-xl'>${myBet.toLocaleString()}</div>
                        </div>
                    ) : (
                        <div className='flex flex-col gap-2 w-full'>
                            <input
                                type='number'
                                value={amount}
                                onChange={(e) => { setAmount(e.target.value); setError('') }}
                                placeholder={`$${minBet} - $${maxBet}`}
                                min={minBet}
                                max={maxBet}
                                className='w-full px-3 py-2 bg-white/5 border border-white/10 rounded text-white text-sm outline-none focus:border-primary/50'
                            />
                            {error && (
                                <p className='text-danger text-xs'>{error}</p>
                            )}
                            <button
                                onClick={handlePlaceBet}
                                disabled={placing || !amount}
                                className='w-full py-2 bg-primary/20 border border-primary/40 text-primary font-bold text-sm uppercase rounded hover:bg-primary/30 duration-300 disabled:opacity-50'
                            >
                                {placing ? '...' : (locale.placeBet || 'Place Bet')}
                            </button>
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}
