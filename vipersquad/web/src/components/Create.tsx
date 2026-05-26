import React, { useEffect } from 'react'
import MenuLayout from './MenuLayout'
import MenuItem from './MenuItem'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import MenuTitle from './MenuTitle'
import cx from 'classnames'
import Spinner from './Spinner'
import { fetchNui } from '../utils/fetchNui'
import { setCurrentMenu, setSquadId, setOwner } from '../slices/globalSlice'


type Props = {}

export default function Create({ }: Props) {
  const { locale } = useSelector((state: RootState) => state.localeSlice)

  const [loading, setLoading] = React.useState<boolean>(true)
  const [check, setCheck] = React.useState<boolean>(false)
  const [squad_name, setSquadName] = React.useState<string>("")
  const [squad_avatar, setSquadAvatar] = React.useState<string>("https://www.proedsolutions.com/wp-content/themes/micron/images/placeholders/placeholder_large_dark.jpg")
  const [squad_privacy, setSquadPrivacy] = React.useState<string>("public")
  const [memberLimit, setMemberLimit] = React.useState<number>(10)
  const dispatch = useDispatch()
  const isCreate = true

  useEffect(() => {
    setLoading(true)
    const delayDebounceFn = setTimeout(() => {
      fetchNui('checkSquadName', squad_name).then((data: any) => {
        setCheck(data)
      }).catch((error) => {
        console.error(error)
      }).finally(() =>
        setLoading(false)
      )
    }, 3000)

    return () => clearTimeout(delayDebounceFn)
  }, [squad_name])

  const createSquad = () => {
    if (loading) return;
    if (squad_name.length < 3) return;
    if (squad_avatar.length < 3) return;
    if (memberLimit < 1) return;
    if (!check) return;

    fetchNui("createSquad", {
      name: squad_name,
      image: squad_avatar,
      privacy: squad_privacy,
      memberLimit: memberLimit
    }).then((data: any) => {
      if (!data) return
      dispatch(setSquadId(data))
      dispatch(setCurrentMenu("members"))
      dispatch(setOwner(true))
    }).catch((e) => {
      console.error(e)
    })
  }

  return (
    <MenuLayout
      props={{
        type: "create",
        endChild: <svg xmlns="http://www.w3.org/2000/svg" onClick={()=>dispatch(setCurrentMenu('squads'))} className='cursor-pointer text-white/[.4] size-6' width="1em" height="1em" viewBox="0 0 28 28">
        <path fill="currentColor" d="M17.754 11c.966 0 1.75.784 1.75 1.75v6.749a5.501 5.501 0 0 1-11.002 0V12.75c0-.966.783-1.75 1.75-1.75zM3.75 11l4.382-.002a2.73 2.73 0 0 0-.621 1.532l-.01.22v6.749c0 1.133.291 2.199.8 3.127A4.5 4.5 0 0 1 2 18.499V12.75A1.75 1.75 0 0 1 3.751 11m16.124-.002L24.25 11c.966 0 1.75.784 1.75 1.75v5.75a4.5 4.5 0 0 1-6.298 4.127l.056-.102c.429-.813.69-1.729.738-2.7l.008-.326V12.75c0-.666-.237-1.276-.63-1.752M14 3a3.5 3.5 0 1 1 0 7a3.5 3.5 0 0 1 0-7m8.003 1a3 3 0 1 1 0 6a3 3 0 0 1 0-6M5.997 4a3 3 0 1 1 0 6a3 3 0 0 1 0-6" />
    </svg>
      }}
    >
      <div className='flex flex-col h-full justify-between'>
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
                  : (squad_name.length > 0 ? <Spinner className='!size-6' /> : <></>)
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
                  <img src={squad_avatar} alt={squad_name} className='w-full h-full object-cover' />
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
          {!isCreate && <MenuItem>
            <button className='flex flex-col items-center justify-center w-full h-full'>
              <p className="text-sm lg:text-xl font-bold text-primary">{locale.deleteSquad}</p>
              <p className='text-white/[.2] text-xs lg:text-sm max-w-64 text-center font-bold'>{locale.deleteSquadDesc}</p>
            </button>
          </MenuItem>}
        </div>
        <MenuItem>
          <button onClick={createSquad} className='flex flex-col items-center justify-center w-full h-full bg-gradient-to-r from-primary-opacity from-0% via-menu-darker via-10% border-l-[0.5556vh] border-primary'>
            <p className="text-sm lg:text-xl font-bold text-primary">{locale.createSquadBtn}</p>
            <p className='text-white/[.2] text-xs lg:text-sm max-w-64 text-center font-bold'>{locale.createSquadDesc}</p>
          </button>
        </MenuItem>
      </div>
    </MenuLayout>
  )
}