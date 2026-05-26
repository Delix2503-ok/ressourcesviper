import React from 'react'
import { useSelector } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'

type ChallengeData = {
    squadId: number
    name: string
    image: string
    members: number
}

type Props = {
    data: ChallengeData
    onClose: () => void
}

export default function WarChallenge({ data, onClose }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [responding, setResponding] = React.useState(false)

    React.useEffect(() => {
        const timeout = setTimeout(() => {
            respond(false)
        }, 30000)
        return () => clearTimeout(timeout)
    }, [])

    const respond = (accept: boolean) => {
        if (responding) return
        setResponding(true)
        fetchNui('respondWar', accept).then(() => {
            onClose()
        }).catch(() => {
            setResponding(false)
        })
    }

    return (
        <div className='absolute inset-0 z-50 flex-center bg-black/60 animate-opacity'>
            <div className='bg-menu-bg border border-menu-border rounded-lg p-6 w-[35vh] animate-popup'>
                <div className='flex flex-col items-center gap-4'>
                    <div className='text-danger font-bold text-lg uppercase tracking-wider'>
                        {locale.warChallenge || 'War Challenge'}
                    </div>
                    <div className='size-[8vh] rounded-full border-2 border-danger overflow-hidden'>
                        <img src={data.image} alt={data.name} className='w-full h-full object-cover' />
                    </div>
                    <div className='text-center'>
                        <div className='text-white font-bold text-xl'>{data.name}</div>
                        <div className='text-white/[.4] text-sm'>
                            {data.members} {locale.members || 'Members'}
                        </div>
                        <div className='text-white/[.6] text-sm mt-2'>
                            {locale.warChallengeDesc || 'wants to challenge your squad!'}
                        </div>
                    </div>
                    <div className='flex flex-row gap-3 w-full mt-2'>
                        <button
                            onClick={() => respond(false)}
                            disabled={responding}
                            className='flex-1 py-2 bg-white/[.05] border border-white/[.1] text-white font-bold text-sm uppercase rounded hover:bg-white/[.1] duration-300 disabled:opacity-50'
                        >
                            {locale.declineWar || 'Decline'}
                        </button>
                        <button
                            onClick={() => respond(true)}
                            disabled={responding}
                            className='flex-1 py-2 bg-danger/20 border border-danger/40 text-danger font-bold text-sm uppercase rounded hover:bg-danger/30 duration-300 disabled:opacity-50'
                        >
                            {locale.acceptWar || 'Accept'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}
