import { useEffect, useState } from 'react'
import { useNuiEvent } from '../hooks/useNuiEvent'

type Props = {
    chatVisible: boolean
}

export default function ChatNotification({ chatVisible }: Props) {
    const [unseenMessageCount, setUnseenMessageCount] = useState(0)

    useNuiEvent('updateUnseenCount', () => {
        if (chatVisible) return
        setUnseenMessageCount(prev => prev + 1)
    })

    useEffect(() => {
        if (chatVisible) {
            setUnseenMessageCount(0)
        }
    }, [chatVisible])

    return (
        <div className='absolute left-2 top-1/2 z-[-1]'>
            {
                (unseenMessageCount > 0) &&
                <div className='animate-appearFromLeft size-10 bg-primary p-5 flex items-center justify-center rounded-md'>

                    <div className='relative cursor-pointer duration-300 hover:opacity-50'>
                        {
                            <div className="absolute inline-flex items-center justify-center size-3 text-[1vh] font-bold text-white rounded-full -top-2 -end-2 ">{unseenMessageCount}</div>
                        }
                        {
                            <svg xmlns="http://www.w3.org/2000/svg" className='text-white' width="1em" height="1em" viewBox="0 0 16 16"><path fill="currentColor" d="M8 15c4.418 0 8-3.134 8-7s-3.582-7-8-7s-8 3.134-8 7c0 1.76.743 3.37 1.97 4.6c-.097 1.016-.417 2.13-.771 2.966c-.079.186.074.394.273.362c2.256-.37 3.597-.938 4.18-1.234A9 9 0 0 0 8 15" /></svg>

                        }
                    </div>
                </div>
            }
        </div>
    )
}