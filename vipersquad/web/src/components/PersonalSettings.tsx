import React, { useEffect } from 'react'
import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { setCurrentMenu, setSquadId } from '../slices/globalSlice'
import MenuLayout from './MenuLayout'
import MenuTitle from "./MenuTitle";
import MenuItem from "./MenuItem";
import cx from 'classnames'
import { fetchNui } from '../utils/fetchNui'
import { setPersonalSettings } from '../slices/globalSlice'

type Props = {
    setChatVisible: (visible: boolean) => void
}

type PersonalSettingProps = {
    value: boolean,
    setValue: (value: boolean) => void
    title: string,
    desc: string
}

const PersonalSetting = ({
    value,
    setValue,
    title,
    desc
}: PersonalSettingProps) => {
    const { locale } = useSelector((state: RootState) => state.localeSlice)

    return (
        <MenuItem>
            <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                <div className='flex flex-col items-start min-w-72'>
                    <p className='text-white font-bold text-md lg:text-lg'>{title}</p>
                    <p className='text-white/[.4] text-sm lg:text-md font-bold'>{desc.replace('{value}', value ? locale.visible : locale.hidden)}</p>
                </div>
                <label className="inline-flex justify-center items-center cursor-pointer">
                    <input type="checkbox" value="" className="sr-only peer" checked={value}
                        onChange={(e) => setValue(!value)}
                    />
                    <div className="relative w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-0 dark:peer-focus:ring-0 dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary"></div>
                </label>
            </div>
        </MenuItem>
    )
}

const PersonalSettingRadio = ({
    title,
    onchange,
    value,
    id
}: {
    title: string
    onchange: (e: any) => void
    value: string
    id: string
}) => {

    return (
        <div className="flex items-center cursor-pointer" onClick={onchange}>
            <input checked={value == id} id={`default-radio-${id}`} type="radio" value="" name="default-radio" className="w-4 h-4 text-primary bg-primary border-gray-300 focus:ring-primary dark:focus:ring-primary dark:ring-offset-gray-800 focus:ring-none dark:bg-gray-700 dark:border-primary" />
            <label htmlFor="default-radio-2" className={cx("ms-2 text-sm duration-300 text-gray-600 font-bold capitalize cursor-pointer", {
                '!text-gray-300': value == id
            })}>{title}</label>
        </div>
    )
}

type PersonalSettingsType = {
    hudVisible: boolean
    nametagsVisible: boolean
    blipsVisible: boolean
    hudAlignment: 'left' | 'right' | 'center'
}

export default function PersonalSettings({
    setChatVisible,
 }: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const { isOwner } = useSelector((state: RootState) => state.globalSlice)
    const dispatch = useDispatch()

    const [personalSettings, setPersonalSettingsState] = React.useState<PersonalSettingsType>({
        hudVisible: true,
        nametagsVisible: true,
        blipsVisible: true,
        hudAlignment: "left"
    })

    useEffect(() => {
        const localSettings = localStorage.getItem('personalSettings')
        if (localSettings) {
            setPersonalSettingsState(JSON.parse(localSettings))
        }
        fetchNui('setPersonalSettings', personalSettings)
    }, [])

    useEffect(() => {
        localStorage.setItem('personalSettings', JSON.stringify(personalSettings))
        fetchNui('setPersonalSettings', personalSettings)
        dispatch(setPersonalSettings(personalSettings))
    }, [personalSettings])
    
    const leaveSquad = () => {
        fetchNui('leaveSquad').then((res) => {
            if (res) {

                dispatch(setSquadId(null))
                dispatch(setCurrentMenu('squads'))
                setChatVisible(false)
            }
        }).catch((err) => {
            console.error(err)
        })
    }

    return (
        <div className='flex flex-col'>
            <MenuTitle>
                <div className='flex-center w-full h-full'>
                    <p className="text-2xl font-bold text-white">{locale.personalSettings}</p>
                </div>
            </MenuTitle>
            {/* HUD Visiblity */}
            <PersonalSetting
                value={personalSettings.hudVisible}
                setValue={()=> setPersonalSettingsState({...personalSettings, hudVisible: !personalSettings.hudVisible})}
                title={locale.showHideHud}
                desc={locale.showHideHudDesc}
            />

            {/* Nametags Visibility */}

            <PersonalSetting
                value={personalSettings.nametagsVisible}
                setValue={()=> setPersonalSettingsState({...personalSettings, nametagsVisible: !personalSettings.nametagsVisible})}
                title={locale.showHideNametags}
                desc={locale.showHideNametagsDesc}
            />

            {/* Blips Visibility */}

            <PersonalSetting
                value={personalSettings.blipsVisible}
                setValue={()=> setPersonalSettingsState({...personalSettings, blipsVisible: !personalSettings.blipsVisible})}
                title={locale.showHideBlips}
                desc={locale.showHideBlipsDesc}
            />

            <MenuItem>
                <div className='w-full h-full flex flex-row justify-between items-center px-8'>
                    <div className='flex flex-col items-start min-w-72'>
                        <p className='text-white font-bold text-md lg:text-lg'>{locale.hudAlignment}</p>
                        <p className='text-white/[.4] text-sm lg:text-md font-bold'>{locale.hudAlignmentDesc}</p>
                    </div>
                    <div className='flex flex-col gap-1'>
                        <PersonalSettingRadio title={locale.left} onchange={() => setPersonalSettingsState({...personalSettings, hudAlignment: "left"})} value={personalSettings.hudAlignment} id={"left"} />
                        {/* <PersonalSettingRadio title={locale.center} onchange={() => setPersonalSettingsState({...personalSettings, hudAlignment: "center"})} value={personalSettings.hudAlignment} id={"center"} /> */}
                        <PersonalSettingRadio title={locale.right} onchange={() => setPersonalSettingsState({...personalSettings, hudAlignment: "right"})} value={personalSettings.hudAlignment} id={"right"} />
                    </div>
                </div>
            </MenuItem>

            {!isOwner && <MenuItem>
                <button onClick={leaveSquad} className='flex flex-col items-center justify-center w-full h-full'>
                    <p className="text-sm lg:text-xl font-bold text-danger">{locale.leaveSquad}</p>
                    <p className='text-white/[.2] text-xs lg:text-sm max-w-64 text-center font-bold'>{locale.leaveSquadDesc}</p>
                </button>
            </MenuItem>}
        </div>
    )
}