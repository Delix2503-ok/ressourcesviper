import React from 'react'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import PublicSquad from './PublicSquad'
import MenuTitle from './MenuTitle'
import Squad from '../types/squad'
import { fetchNui } from '../utils/fetchNui'
import cx from 'classnames'
import { useNuiEvent } from '../hooks/useNuiEvent'
import MenuLayout from './MenuLayout'
import { setCurrentMenu } from '../slices/globalSlice'
import Spinner from './Spinner'
import { i } from 'vite/dist/node/types.d-aGj9QkWt'

type Props = {}

const squadData: Squad[] = [
    {
        id: 1,
        image: 'https://via.placeholder.com/150',
        name: 'GFX Squad',
        members: 9,
        maxMembers: 9,
    },
    {
        id: 2,
        image: 'https://via.placeholder.com/150',
        name: 'THY Squad',
        members: 7,
        maxMembers: 18,
    },
    {
        id: 3,
        image: 'https://via.placeholder.com/150',
        name: 'GFX Squad',
        members: 12,
        maxMembers: 15,
    }
]

const invitesData: Squad[] = [
    {
        id: 1,
        image: 'https://via.placeholder.com/150',
        name: 'GFX Squad',
        members: 9,
        maxMembers: 9,
    },
]

export default function PublicSquads({ }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [squads, setSquads] = React.useState<Squad[]>([])
    const [invites, setInvites] = React.useState<Squad[]>([])
    const [loading, setLoading] = React.useState<boolean>(true)
    const [inviteCount, setInviteCount] = React.useState<number>(0)
    const [invitesVisible, setInvitesVisible] = React.useState<boolean>(false)
    const [filter, setFilter] = React.useState<string>('')
    const [joinLoading, setJoinLoading] = React.useState<number | null>(null)
    const dispatch = useDispatch()

    const openInvites = () => {
        setInvitesVisible(!invitesVisible)
        setInviteCount(0)
    }

    useNuiEvent('setInviteCount', (data: number) => {
        setInviteCount(data)
    })

    React.useEffect(() => {
        fetchSquads()
    }, [])

    React.useEffect(() => {
        if (invitesVisible) fetchInvites()
    }, [invitesVisible])

    const fetchSquads = () => {
        setLoading(true)
        fetchNui('getSquads').then((data: any) => {
            setSquads(Array.isArray(data) ? data : [])
        }).catch((error) => {
            console.error(error)
            setSquads(squadData)
        }).finally(() => {
            setLoading(false)
        })
    }

    const fetchInvites = () => {
        setLoading(true)
        fetchNui('getInvites').then((data: any) => {
            setInvites(Array.isArray(data) ? data : [])
        }).catch((error) => {
            console.error(error)
            setInvites(invitesData)
        }).finally(() => {
            setLoading(false)
        }
        )
    }

    return (
        <MenuLayout
            props={
                {
                    squads: squads,
                    fetchSquads: !invitesVisible ? fetchSquads : fetchInvites,
                    loading: loading,
                    type: "squads",
                    startChild: <>
                        <input type='text' onChange={(e) => setFilter(e.target.value)} value={filter} placeholder={locale.search} className='max-w-24 bg-transparent font-bold outline-none text-xs lg:text-lg text-white/[.4] placeholder:text-white/[.4]' />
                        <svg xmlns="http://www.w3.org/2000/svg" onClick={fetchSquads} className={cx('text-lg text-white/[.4] cursor-pointer duration-300 hover:text-white', {
                            'animate-spin !text-white': loading
                        })} width="1em" height="1em" viewBox="0 0 24 24">
                            <path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 11A8.1 8.1 0 0 0 4.5 9M4 5v4h4m-4 4a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4" />
                        </svg>
                    </>,
                    endChild: <div className='flex flex-row items-center justify-center gap-2 text-white/[.4]'>
                        <p className='font-bold text-xs lg:text-sm'>
                            {locale.listedCount.replace('{count}', (invitesVisible ? invites : squads).length.toString())}
                        </p>
                        <div className='relative cursor-pointer'
                            onClick={openInvites}
                        >
                            {
                                inviteCount > 0 && <div className="absolute inline-flex items-center justify-center size-4 text-[1vh] font-bold text-white bg-danger rounded-full -top-2 -end-2">{inviteCount}</div>
                            }
                            {
                                !invitesVisible ?
                                    <svg xmlns="http://www.w3.org/2000/svg" className='size-5' width="1em" height="1em" viewBox="0 0 24 24"><g fill="none"><path d="m12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035q-.016-.005-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.017-.018m.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093q.019.005.029-.008l.004-.014l-.034-.614q-.005-.018-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01z" /><path fill="currentColor" d="M17 3a3 3 0 0 1 2.995 2.824L20 6v4.35l.594-.264c.614-.273 1.322.15 1.4.798L22 11v8a2 2 0 0 1-1.85 1.995L20 21H4a2 2 0 0 1-1.995-1.85L2 19v-8c0-.672.675-1.147 1.297-.955l.11.041l.593.264V6a3 3 0 0 1 2.824-2.995L7 3zm0 2H7a1 1 0 0 0-1 1v5.239l6 2.667l6-2.667V6a1 1 0 0 0-1-1m-5 3a1 1 0 0 1 .117 1.993L12 10h-2a1 1 0 0 1-.117-1.993L10 8z" /></g></svg>
                                    :
                                    <svg onClick={() => setInvitesVisible(false)} xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 28 28"><path fill="currentColor" d="M17.754 11c.966 0 1.75.784 1.75 1.75v6.749a5.501 5.501 0 0 1-11.002 0V12.75c0-.966.783-1.75 1.75-1.75zM3.75 11l4.382-.002a2.73 2.73 0 0 0-.621 1.532l-.01.22v6.749c0 1.133.291 2.199.8 3.127A4.5 4.5 0 0 1 2 18.499V12.75A1.75 1.75 0 0 1 3.751 11m16.124-.002L24.25 11c.966 0 1.75.784 1.75 1.75v5.75a4.5 4.5 0 0 1-6.298 4.127l.056-.102c.429-.813.69-1.729.738-2.7l.008-.326V12.75c0-.666-.237-1.276-.63-1.752M14 3a3.5 3.5 0 1 1 0 7a3.5 3.5 0 0 1 0-7m8.003 1a3 3 0 1 1 0 6a3 3 0 0 1 0-6M5.997 4a3 3 0 1 1 0 6a3 3 0 0 1 0-6" /></svg>
                            }
                        </div>

                    </div>
                }
            }
        >
            <div className='flex flex-col overflow-y-auto'>
                <div className='overflow-y-auto'>

                    {
                        (invitesVisible ? invites : squads).length == 0 ?
                            <div className='flex-center text-white text-lg font-bold uppercase h-24'>
                                {
                                    loading ?
                                        <Spinner />
                                        : locale[invitesVisible ? 'noInvites' : 'noSquads']
                                }
                            </div>
                            : (invitesVisible ? invites : squads).map((squad, index) => {
                                if (filter.length > 0 && !squad.name.toLowerCase().includes(filter.toLowerCase())) return null

                                return (
                                    <PublicSquad key={index} first={index === 0} squadData={squad} joinLoading={joinLoading} isInvite={invitesVisible} setJoinLoading={setJoinLoading} setInvites={setInvites} />
                                )
                            })
                    }
                </div>
                {!invitesVisible &&
                    <MenuTitle>
                        <div className='w-full h-full flex-center text-xs lg:text-lg text-white gap-2 cursor-pointer duration-300 hover:opacity-70'
                            onClick={() => dispatch(setCurrentMenu('create'))}
                        >
                            <p className='font-bold uppercase'>
                                {locale.createSquadBtn}
                            </p>
                            <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 12 12"><path fill="currentColor" d="M6.5 1.75a.75.75 0 0 0-1.5 0V5H1.75a.75.75 0 0 0 0 1.5H5v3.25a.75.75 0 0 0 1.5 0V6.5h3.25a.75.75 0 0 0 0-1.5H6.5z" /></svg>
                        </div>
                    </MenuTitle>
                }
            </div>
        </MenuLayout>
    )
}