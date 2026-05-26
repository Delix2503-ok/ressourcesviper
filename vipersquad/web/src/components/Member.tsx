import React from 'react'
import MenuItem from './MenuItem'
import MemberType from '../types/member'
import { useSelector } from 'react-redux'
import { RootState } from '../store'
import { fetchNui } from '../utils/fetchNui'
import { Ellipsis, MapPin, UserMinus, Check, UserPlus } from 'lucide-react'

type Props = {
    first?: boolean
    memberData: MemberType
    isInvite?: boolean
}

export default function Member({
    first,
    memberData,
    isInvite
}: Props) {
    const { isOwner, playerId } = useSelector((state: RootState) => state.globalSlice)
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const [invited, setInvited] = React.useState<boolean>(false)

    const setWaypoint = () => {
        fetchNui('setWaypoint', memberData.coords)
    }

    const kickMember = () => {
        fetchNui('kickMember', memberData.id)
    }

    const inviteMember = () => {
        if (invited) return
        fetchNui('inviteMember', memberData.id).then((res) => {
            if (res) {
                setInvited(true)
            }
        })
    }

    return (
        <MenuItem first={first}>
            <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                <div className='flex flex-row items-center gap-2'>
                    <div className='size-[6vh] rounded-full border-2 border-primary overflow-hidden'>
                        <img src={memberData.image} alt={memberData.name} className='w-full h-full object-cover' />
                    </div>
                    <div>
                        <div className='text-white font-bold text-sm lg:text-xl'>{memberData.name}</div>
                        {!isInvite && <div className='text-white/[.4] text-xs lg:text-xl font-bold'>{first ? locale.owner : locale.member}</div>}
                    </div>
                </div>
                {isOwner && memberData.id != playerId && !isInvite && <div className='flex flex-row items-center gap-4 group'>
                    <div className='absolute right-4 text-primary'>
                        <Ellipsis size={24} className='group-hover:opacity-0 duration-300' />
                    </div>
                    <div className='absolute opacity-0 group-hover:opacity-100 flex flex-row items-center gap-2 right-4 text-primary'>
                        <MapPin size={18} onClick={setWaypoint} className='duration-300 hover:opacity-50 cursor-pointer' />
                        <UserMinus size={20} onClick={kickMember} className='cursor-pointer hover:opacity-50' />
                    </div>
                </div>}
                {
                    isInvite && <div className='flex flex-row items-center gap-4 group cursor-pointer hover:opacity-70 duration-300'
                        onClick={inviteMember}
                    >
                        <div className='absolute right-4 text-primary text-4xl'>
                            {
                                invited ? <Check size={24} /> : <UserPlus size={22} />
                            }
                        </div>
                    </div>
                }
            </div>
        </ MenuItem>
    )
}