import React, { useEffect } from 'react'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { setCurrentMenu, setOwner, setSquadId } from '../slices/globalSlice'
import MenuLayout from './MenuLayout'
import MenuTitle from "./MenuTitle";
import MenuItem from "./MenuItem";
import cx from 'classnames'
import Spinner from './Spinner'
import { fetchNui } from '../utils/fetchNui'

type Props = {
    isCreate?: boolean
    setChatVisible: (visible: boolean) => void
}

export default function OwnerSettings({ isCreate, setChatVisible }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const { squad } = useSelector((state: RootState) => state.globalSlice)
    const dispatch = useDispatch()

    const [loading, setLoading] = React.useState<boolean>(true)
    const [check, setCheck] = React.useState<boolean>(true)
    const [squad_name, setSquadName] = React.useState<string>(squad.name)
    const [squad_avatar, setSquadAvatar] = React.useState<string>(squad.image)
    const [squad_privacy, setSquadPrivacy] = React.useState<string>(squad.settings.privacy)
    const [memberLimit, setMemberLimit] = React.useState<number>(squad.settings.memberLimit)
    const [submitting, setSubmitting] = React.useState<boolean>(false)

    useEffect(() => {
        setLoading(true)
        const delayDebounceFn = setTimeout(() => {
            setLoading(false)
        }, 3000)

        return () => clearTimeout(delayDebounceFn)
    }, [squad_name])

    useEffect(() => {
        fetchNui('getSquadSettings').then((data: any) => {
            setSquadName(data.name)
            setSquadAvatar(data.image)
            setSquadPrivacy(data.privacy)
            setMemberLimit(data.memberLimit)
        }).catch((error) => {
            console.error(error)
        })
    }, [])

    const deleteSquad = () => {
        fetchNui("deleteSquad").then((res) => {
            dispatch(setSquadId(null))
            dispatch(setCurrentMenu('squads'))
            dispatch(setOwner(false))
            setChatVisible(false)
        }).catch((error) => {
            console.error(error)
        })
    }

    const handleSubmit = () => {
        if (loading) return;
        if (squad_name.length < 3) return;
        if (squad_avatar.length < 3) return;
        if (memberLimit < 1) return;
        if (!check) return;

        setSubmitting(true)
        fetchNui("updateSquadSettings", {
            name: squad_name,
            image: squad_avatar,
            privacy: squad_privacy,
            memberLimit: memberLimit
        }).then((data: any) => {
        }).catch((e) => {
            console.error(e)
        }).finally(() => {
            setTimeout(() => {

                setSubmitting(false)
            }, 500);
        })
    }

    return (
        <div className='flex flex-col'>
            {!isCreate && <MenuTitle>
                <div className='flex-center w-full h-full'>
                    <p className="text-2xl font-bold text-white">{locale.ownerSettings}</p>
                </div>
            </MenuTitle>}
            {/* Squad Name */}
            <MenuItem>
                <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                    <div className='flex flex-col items-start min-w-72'>
                        <p className='text-white font-bold text-md lg:text-lg'>{locale.squadName}</p>
                        <input type='text' className='placeholder:text-white/[.4] text-white/[.7] bg-transparent text-sm lg:text-md outline-none font-bold' value={squad_name} onChange={(e) => setSquadName(e.target.value)}
                            placeholder={locale.squadNamePlaceholder} />
                    </div>
                    <div className='flex-center size-[6vh]'>
                        {!loading ? <div className={cx('flex-center group size-5 lg:size-7 rounded-full text-white', {
                            "bg-primary": !check,
                            "bg-success": check
                        })}>
                            {
                                check ?
                                    <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 26 26"><path fill="currentColor" d="m22.567 4.73l-1.795-1.219a1.09 1.09 0 0 0-1.507.287l-8.787 12.959l-4.039-4.039a1.09 1.09 0 0 0-1.533 0l-1.533 1.536a1.084 1.084 0 0 0 0 1.534L9.582 22c.349.347.895.615 1.387.615s.988-.31 1.307-.774l10.58-15.606a1.085 1.085 0 0 0-.289-1.505" /></svg>
                                    :
                                    <svg xmlns="http://www.w3.org/2000/svg" className='text-xl' width="1em" height="1em" viewBox="0 0 24 24"><path fill="currentColor" d="M18.3 5.71a.996.996 0 0 0-1.41 0L12 10.59L7.11 5.7A.996.996 0 1 0 5.7 7.11L10.59 12L5.7 16.89a.996.996 0 1 0 1.41 1.41L12 13.41l4.89 4.89a.996.996 0 1 0 1.41-1.41L13.41 12l4.89-4.89c.38-.38.38-1.02 0-1.4" /></svg>
                            }
                        </div>
                            : <Spinner className='!size-6' />
                        }
                    </div>
                </div>
            </MenuItem>
            {/* Squad Avatar */}
            <MenuItem>
                <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                    <div className='flex flex-col items-start'>
                        <p className='text-white font-bold text-md lg:text-lg'>{locale.squadAvatar}</p>
                        <input type='text' className='placeholder:text-white/[.4] text-white/[.7] bg-transparent text-sm lg:text-md outline-none font-bold'
                            value={squad_avatar} onChange={(e) => setSquadAvatar(e.target.value)}
                            placeholder={locale.squadNamePlaceholder}
                        />
                    </div>
                    <div className='flex-center'>
                        <div className="w-[6vh] h-[6vh] flex items-center rounded-full border-2 border-primary overflow-hidden">
                            <img src={squad_avatar} alt={squad.name} className='w-full h-full object-cover' />
                        </div>
                    </div>
                </div>
            </MenuItem>
            {/* Squad Privacy */}
            <MenuItem>
                <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                    <div className='flex flex-col items-start min-w-72'>
                        <p className='text-white font-bold text-md lg:text-lg'>{locale.squadPrivacy}</p>
                        <p className='text-white/[.4] text-sm lg:text-md font-bold'>{locale.squadPrivacyDesc.replace('{value}', squad_privacy)}</p>
                    </div>
                    <label className="inline-flex justify-center items-center cursor-pointer size-[6vh]">
                        <input type="checkbox" value="" className="sr-only peer" checked={squad_privacy == "private"}
                            onChange={(e) => setSquadPrivacy(e.target.checked ? "private" : "public")}
                        />
                        <div className="relative w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-0 dark:peer-focus:ring-0 dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary"></div>
                    </label>
                </div>
            </MenuItem>
            {/* Member Limit */}
            <MenuItem>
                <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                    <div className='flex flex-col items-start min-w-72'>
                        <p className='text-white font-bold text-md lg:text-lg'>{locale.memberLimit}</p>
                        <p className='text-white/[.4] text-xs lg:text-md font-bold max-w-52 lg:max-w-72'>{locale.memberLimitDesc}</p>
                    </div>
                    <div className='flex-center size-[6vh]'>
                        <input type='text' className='max-w-10 text-center placeholder:text-white/[.4] text-white border-b bg-transparent text-3xl outline-none font-bold'
                            value={memberLimit} maxLength={2} onChange={(e) => setMemberLimit(isNaN(Number(e.target.value)) ? 0 : Number(e.target.value))}
                            placeholder="0"
                        />
                    </div>
                </div>
            </MenuItem>
            <MenuItem>
                {!submitting ? <button onClick={handleSubmit} className='flex flex-col items-center justify-center w-full h-full bg-gradient-to-r from-primary-opacity from-0% via-menu-darker via-10% border-l-[0.5556vh] border-primary'>
                    <p className="text-sm lg:text-xl font-bold text-[#fff]">{locale.updateSettings}</p>
                    <p className='text-white/[.2] text-xs lg:text-sm max-w-64 text-center font-bold'>{locale.updateSettingsDesc}</p>
                </button> : <div className='flex items-center justify-center w-full h-full'>
                    <Spinner className='!size-6' />
                </div>}
            </MenuItem>
            {!isCreate && <MenuItem>
                <button onClick={deleteSquad} className='flex flex-col items-center justify-center w-full h-full'>
                    <p className="text-sm lg:text-xl font-bold text-danger">{locale.deleteSquad}</p>
                    <p className='text-white/[.2] text-xs lg:text-sm max-w-64 text-center font-bold'>{locale.deleteSquadDesc}</p>
                </button>
            </MenuItem>}
        </div>
    )
}