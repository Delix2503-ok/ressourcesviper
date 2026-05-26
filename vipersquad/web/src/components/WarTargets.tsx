import React from 'react'
import MenuLayout from './MenuLayout'
import MenuItem from './MenuItem'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'
import Spinner from './Spinner'
import { setCurrentMenu } from '../slices/globalSlice'
import { useNuiEvent } from '../hooks/useNuiEvent'
import { ArrowLeft, Swords } from 'lucide-react'

type WarTarget = {
    id: number
    name: string
    image: string
    members: number
}

const mockTargets: WarTarget[] = [
    { id: 1, name: 'Alpha Squad', image: 'https://i.pravatar.cc/150?img=10', members: 4 },
    { id: 2, name: 'Bravo Team', image: 'https://i.pravatar.cc/150?img=11', members: 3 },
    { id: 3, name: 'Delta Force', image: 'https://i.pravatar.cc/150?img=12', members: 6 },
]

export default function WarTargets() {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [targets, setTargets] = React.useState<WarTarget[]>([])
    const [loading, setLoading] = React.useState(true)
    const [challenged, setChallenged] = React.useState(false)
    const dispatch = useDispatch()

    React.useEffect(() => {
        setLoading(true)
        fetchNui('getWarTargets', null, mockTargets).then((data: any) => {
            setTargets(data)
        }).catch(() => {
            setTargets(mockTargets)
        }).finally(() => {
            setLoading(false)
        })
    }, [])

    const challengeSquad = (targetId: number) => {
        fetchNui('challengeSquad', targetId).then((res: any) => {
            if (res) {
                setChallenged(true)
                setTimeout(() => {
                    setChallenged(false)
                    dispatch(setCurrentMenu("members"))
                }, 3000)
            }
        })
    }

    useNuiEvent('warDeclined', () => {
        setChallenged(false)
    })

    return (
        <MenuLayout
            props={{
                type: 'warTargets',
                endChild: <div className='flex flex-row text-white/[.4] gap-2 items-center'>
                    <ArrowLeft size={18} onClick={() => dispatch(setCurrentMenu("members"))} className='cursor-pointer duration-300 hover:opacity-50' />
                </div>
            }}
        >
            <div className='flex flex-col overflow-y-auto'>
                <div className='overflow-y-auto'>
                    {challenged ? (
                        <div className='flex-center text-primary text-lg font-bold uppercase h-24 animate-pulse'>
                            {locale.warChallenged || 'Challenge sent!'}
                        </div>
                    ) : targets.length === 0 ? (
                        <div className='flex-center text-white text-lg font-bold uppercase h-24'>
                            {loading ? <Spinner /> : (locale.noWarTargets || 'No available squads')}
                        </div>
                    ) : (
                        targets.map((target, index) => (
                            <MenuItem key={target.id} first={index === 0}>
                                <div className='w-full h-full flex flex-row justify-between items-center px-8 cursor-pointer hover:opacity-80 duration-300'
                                    onClick={() => challengeSquad(target.id)}
                                >
                                    <div className='flex flex-row items-center gap-2'>
                                        <div className='size-[6vh] rounded-full border-2 border-primary overflow-hidden'>
                                            <img src={target.image} alt={target.name} className='w-full h-full object-cover' />
                                        </div>
                                        <div>
                                            <div className='text-white font-bold text-sm lg:text-xl'>{target.name}</div>
                                            <div className='text-white/[.4] text-xs lg:text-sm font-bold'>{target.members} {locale.members || 'Members'}</div>
                                        </div>
                                    </div>
                                    <Swords size={22} className='text-primary' />
                                </div>
                            </MenuItem>
                        ))
                    )}
                </div>
            </div>
        </MenuLayout>
    )
}
