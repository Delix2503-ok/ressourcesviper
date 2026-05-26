import React from 'react'
import MenuItem from './MenuItem'
import Squad from '../types/squad'
import { useSelector } from 'react-redux'
import { RootState } from '../store'
import cx from 'classnames'
import { fetchNui } from '../utils/fetchNui'
import { useDispatch } from 'react-redux'
import { setSquadId, setCurrentMenu } from '../slices/globalSlice'
import Spinner from './Spinner'

type Props = {
    first?: boolean
    squadData: Squad
    joinLoading: number | null
    setJoinLoading: (value: number | null) => void
    isInvite?: boolean
    setInvites: (value: any) => void
}

export default function PublicSquad({
    first,
    squadData,
    joinLoading,
    setJoinLoading,
    isInvite,
    setInvites
}: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const dispatch = useDispatch()

    const joinSquad = () => {
        setJoinLoading(squadData.id)
        fetchNui('joinSquad', squadData.id).then((res) => {
            if (res) {

                dispatch(setSquadId(squadData.id))
                dispatch(setCurrentMenu('members'))
            }
        }).catch((error) => {
            console.error(error)
        }).finally(() => {
            setJoinLoading(null)
        })
    }

    const removeInvite = (id: number) => {
        fetchNui('removeInvite', id).then((res) => {
            setInvites((prev: any) => prev.filter((squad: any) => squad.id !== squadData.id))
        }).catch((error) => {
            console.error(error)
        })
    }

    return (
        <MenuItem first={first}>
            <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                <div className='flex flex-row items-center gap-4'>
                    <div className='w-16 h-16 rounded-full border-2 border-primary overflow-hidden'>
                        <img src={squadData.image} alt={squadData.name} />
                    </div>
                    <div className='flex flex-col font-bold'>
                        <div className='text-white text-lg'>{squadData.name}</div>
                        <div className='text-white/[.4] text-md uppercase'>{squadData.members}/{squadData.maxMembers} {locale.members}</div>
                    </div>
                </div>
                <div className='flex flex-row gap-2 text-primary text-2xl duration-300 flex-center'>
                    <button className={cx('cursor-pointer', {
                        'grayscale': squadData.members === squadData.maxMembers || (!!joinLoading && joinLoading !== squadData.id),
                        'hover:opacity-70': squadData.members !== squadData.maxMembers && !joinLoading
                    })}
                        disabled={squadData.members === squadData.maxMembers || !!joinLoading}
                        onClick={joinSquad}
                    >

                        {
                            joinLoading == squadData.id ? <Spinner className='!size-6 text-primary' /> :
                                <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 4h10v14a2 2 0 0 1-2 2H9m3-5l3-3m0 0l-3-3m3 3H5" /></svg>
                        }
                    </button>
                    {
                        isInvite && <svg xmlns="http://www.w3.org/2000/svg" className='cursor-pointer text-danger' width="1em" height="1em" viewBox="0 0 24 24"
                            onClick={() => removeInvite(squadData.id)}>
                        <g fill="none" fill-rule="evenodd"><path d="m12.593 23.258l-.011.002l-.071.035l-.02.004l-.014-.004l-.071-.035q-.016-.005-.024.005l-.004.01l-.017.428l.005.02l.01.013l.104.074l.015.004l.012-.004l.104-.074l.012-.016l.004-.017l-.017-.427q-.004-.016-.017-.018m.265-.113l-.013.002l-.185.093l-.01.01l-.003.011l.018.43l.005.012l.008.007l.201.093q.019.005.029-.008l.004-.014l-.034-.614q-.005-.018-.02-.022m-.715.002a.02.02 0 0 0-.027.006l-.006.014l-.034.614q.001.018.017.024l.015-.002l.201-.093l.01-.008l.004-.011l.017-.43l-.003-.012l-.01-.01z" /><path fill="currentColor" d="m12 14.122l5.303 5.303a1.5 1.5 0 0 0 2.122-2.122L14.12 12l5.304-5.303a1.5 1.5 0 1 0-2.122-2.121L12 9.879L6.697 4.576a1.5 1.5 0 1 0-2.122 2.12L9.88 12l-5.304 5.304a1.5 1.5 0 1 0 2.122 2.12z" /></g></svg>
                    }
                </div>
            </div>
        </MenuItem>
    )
}