import React from 'react'
import MenuLayout from './MenuLayout'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'
import LeaderboardEntry from '../types/leaderboard'
import LeaderboardItem from './LeaderboardItem'
import Spinner from './Spinner'
import { setCurrentMenu } from '../slices/globalSlice'
import { useNuiEvent } from '../hooks/useNuiEvent'
import { ArrowLeft } from 'lucide-react'

const mockLeaderboard: LeaderboardEntry[] = [
    { name: 'John Doe', image: 'https://i.pravatar.cc/150?img=1', kills: 15, deaths: 3, kd: '5.00' },
    { name: 'Jane Doe', image: 'https://i.pravatar.cc/150?img=2', kills: 10, deaths: 5, kd: '2.00' },
    { name: 'John Smith', image: 'https://i.pravatar.cc/150?img=3', kills: 8, deaths: 8, kd: '1.00' },
    { name: 'Jane Smith', image: 'https://i.pravatar.cc/150?img=4', kills: 5, deaths: 10, kd: '0.50' },
]

export default function Leaderboard() {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [entries, setEntries] = React.useState<LeaderboardEntry[]>([])
    const [loading, setLoading] = React.useState(true)
    const dispatch = useDispatch()

    const fetchLeaderboard = () => {
        setLoading(true)
        fetchNui('getLeaderboard', null, mockLeaderboard).then((data: any) => {
            setEntries(data)
        }).catch(() => {
            setEntries(mockLeaderboard)
        }).finally(() => {
            setLoading(false)
        })
    }

    React.useEffect(() => {
        fetchLeaderboard()
    }, [])

    useNuiEvent('leaderboardUpdate', () => {
        fetchLeaderboard()
    })

    return (
        <MenuLayout
            props={{
                type: 'leaderboard',
                endChild: <div className='flex flex-row text-white/[.4] gap-2 items-center'>
                    <ArrowLeft size={18} onClick={() => dispatch(setCurrentMenu("members"))} className='cursor-pointer duration-300 hover:opacity-50' />
                </div>
            }}
        >
            <div className='flex flex-col overflow-y-auto'>
                <div className='overflow-y-auto'>
                    <div className='flex flex-row justify-between items-center px-8 py-2 text-white/[.3] text-xs font-bold uppercase'>
                        <div className='flex flex-row items-center gap-3 flex-[4]'>
                            <div className='w-8 text-center'>#</div>
                            <div>{locale.members || 'Player'}</div>
                        </div>
                        <div className='flex flex-row items-center flex-[3] justify-end gap-6'>
                            <div>{locale.kills || 'Kills'}</div>
                            <div>{locale.deaths || 'Deaths'}</div>
                            <div className='min-w-[4vh]'>{locale.kd || 'K/D'}</div>
                        </div>
                    </div>
                    {entries.length === 0 ? (
                        <div className='flex-center text-white text-lg font-bold uppercase h-24'>
                            {loading ? <Spinner /> : (locale.noStats || 'No stats yet')}
                        </div>
                    ) : (
                        entries.map((entry, index) => (
                            <LeaderboardItem key={index} entry={entry} rank={index + 1} first={index === 0} />
                        ))
                    )}
                </div>
            </div>
        </MenuLayout>
    )
}
