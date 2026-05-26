import { useSelector, useDispatch } from 'react-redux'
import { RootState } from '../store'
import { setCurrentMenu } from '../slices/globalSlice'
import MenuLayout from './MenuLayout'
import OwnerSettings from './OwnerSettings'
import PersonalSettings from './PersonalSettings'

type Props = {
    setChatVisible: (visible: boolean) => void
}

export default function Settings({
    setChatVisible,
}: Props) {
    const { isOwner } = useSelector((state: RootState) => state.globalSlice)
    const dispatch = useDispatch()

    return (
        <MenuLayout props={{
            type: 'settings',
            endChild: (
                <svg xmlns="http://www.w3.org/2000/svg" onClick={() => dispatch(setCurrentMenu('members'))} className='cursor-pointer text-white/[.4] size-6' width="1em" height="1em" viewBox="0 0 28 28">
                    <path fill="currentColor" d="M17.754 11c.966 0 1.75.784 1.75 1.75v6.749a5.501 5.501 0 0 1-11.002 0V12.75c0-.966.783-1.75 1.75-1.75zM3.75 11l4.382-.002a2.73 2.73 0 0 0-.621 1.532l-.01.22v6.749c0 1.133.291 2.199.8 3.127A4.5 4.5 0 0 1 2 18.499V12.75A1.75 1.75 0 0 1 3.751 11m16.124-.002L24.25 11c.966 0 1.75.784 1.75 1.75v5.75a4.5 4.5 0 0 1-6.298 4.127l.056-.102c.429-.813.69-1.729.738-2.7l.008-.326V12.75c0-.666-.237-1.276-.63-1.752M14 3a3.5 3.5 0 1 1 0 7a3.5 3.5 0 0 1 0-7m8.003 1a3 3 0 1 1 0 6a3 3 0 0 1 0-6M5.997 4a3 3 0 1 1 0 6a3 3 0 0 1 0-6" />
                </svg>
            )
        }}>
            <div className="flex flex-col overflow-y-auto">
                {isOwner && <OwnerSettings
                    setChatVisible={setChatVisible}
                />}
                <PersonalSettings
                    setChatVisible={setChatVisible}
                />
            </div>
        </MenuLayout>
    )
}