import React, { useEffect } from 'react'
import MenuLayout from './MenuLayout'
import MenuTitle from './MenuTitle'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'
import MemberType from '../types/member'
import Member from './Member'
import Spinner from './Spinner'
import { setCurrentMenu } from '../slices/globalSlice'
import { useNuiEvent } from '../hooks/useNuiEvent'
import { MessageCircle, Trophy, Swords, Settings, UserPlus } from 'lucide-react'

type Props = {
    setChatVisible: (visible: boolean) => void
    chatVisible: boolean
}

const membersData: MemberType[] = [
    {
        id: 1,
        name: 'John Doe',
        image: 'https://i.pravatar.cc/150?img=1',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 2,
        name: 'Jane Doe',
        image: 'https://i.pravatar.cc/150?img=2',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 3,
        name: 'John Smith',
        image: 'https://i.pravatar.cc/150?img=3',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
    {
        id: 4,
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        distance: Math.random() * 100,
        coords: {
            x: Math.random() * 100,
            y: Math.random() * 100,
        }
    },
]

export default function Members({
    setChatVisible, chatVisible
}: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const { squadId, isOwner } = useSelector((state: RootState) => state.globalSlice)
    const [members, setMembers] = React.useState<MemberType[]>([])
    const [loading, setLoading] = React.useState(true)
    const [isInvite, setIsInvite] = React.useState(false)
    const [inviteMembers, setInviteMembers] = React.useState<MemberType[]>([])
    const [unseenMessageCount, setUnseenMessageCount] = React.useState(0)
    const dispatch = useDispatch()

    React.useEffect(() => {
        if (!squadId) {
            setLoading(false)
            return
        }
        setLoading(true)
        fetchNui('getMembers').then((data: any) => {
            setMembers(Array.isArray(data) ? data : [])
        }).catch((err) => {
            console.error(err)
            setMembers(membersData)
        }).finally(() => {
            setLoading(false)
        })
        setUnseenMessageCount(0)
    }, [squadId])

    useNuiEvent('updateMembers', (data: MemberType) => {
        setMembers([...members, data])
    })

    useNuiEvent('updateUnseenCount', () => {
        if (!chatVisible) setUnseenMessageCount(prev => prev + 1)
    })

    useNuiEvent('removeMember', (id: number) => {
        setMembers(members.filter((member) => member.id !== id))
    })

    const [filter, setFilter] = React.useState<string>('')

    const fetchPlayers = () => {
        setLoading(true)
        fetchNui('getPlayers').then((data: any) => {
            setInviteMembers(Array.isArray(data) ? data : [])
        }).catch((err) => {
            console.error(err)
            setInviteMembers(membersData)
        }).finally(() => {
            setLoading(false)
        })
    }

    useEffect(() => {
        if (isInvite) fetchPlayers()
    }, [isInvite])

    const openChat = () => {
        setChatVisible(true)
        setUnseenMessageCount(0)
    }

    return (
        <MenuLayout
            props={{
                type: isInvite ? "invites" : "members",
                startChild: <>
                    <input type='text' onChange={(e) => setFilter(e.target.value)} value={filter} placeholder={locale.search} className='max-w-24 bg-transparent font-bold outline-none text-xs lg:text-lg text-white/[.4] placeholder:text-white/[.4]' />
                </>,
                endChild: <div className='flex flex-row text-white/[.4] gap-2 items-center justify-between'>

                    <div className='relative cursor-pointer duration-300 hover:opacity-50'
                        onClick={openChat}
                    >
                        {
                            (unseenMessageCount > 0 && !chatVisible) && <div className="absolute inline-flex items-center justify-center size-4 text-[1vh] font-bold text-white bg-danger rounded-full -top-2 -end-2 ">{unseenMessageCount}</div>
                        }
                        <MessageCircle size={18} onClick={() => setChatVisible(true)} />
                    </div>

                    <Trophy size={18} onClick={() => dispatch(setCurrentMenu("leaderboard"))} className='cursor-pointer duration-300 hover:opacity-50' />

                    {isOwner && <Swords size={18} onClick={() => dispatch(setCurrentMenu("warTargets"))} className='cursor-pointer duration-300 hover:opacity-50' />}

                    <Settings size={18} onClick={() => dispatch(setCurrentMenu("settings"))} className='cursor-pointer duration-300 hover:opacity-50' />

                </div>
            }}
        >
            <div className='flex flex-col overflow-y-auto'>
                <div className='overflow-y-auto'>
                    {
                        members.length == 0 ?
                            <div className='flex-center text-white text-lg font-bold uppercase h-24'>
                                {
                                    loading ?
                                        <Spinner />
                                        : locale.noMembers
                                }
                            </div>
                            : (!isInvite ? members : inviteMembers).map((member, index) => {
                                if (filter && !member.name.toLowerCase().includes(filter.toLowerCase()) && !member.id.toString().includes(filter)) return null

                                return (
                                    <Member key={index} first={index === 0} memberData={member} isInvite={isInvite} />
                                )
                            })
                    }
                </div>
                {isOwner && <MenuTitle>
                    <div className='w-full h-full flex-center text-xs lg:text-lg text-white gap-2 cursor-pointer duration-300 hover:opacity-70'
                        onClick={() => setIsInvite(!isInvite)}
                    >
                        <p className='font-bold uppercase'>
                            {isInvite ? locale.returnMembers : locale.inviteMember}
                        </p>
                        {!isInvite && <UserPlus size={20} />}
                    </div>
                </MenuTitle>}
            </div>
        </MenuLayout>
    )
}