import React, { useEffect, useRef } from 'react'
import { useSelector } from 'react-redux'
import { RootState } from '../store'
import ChatBubble from './ChatBubble'
import { fetchNui } from '../utils/fetchNui'
import { useNuiEvent } from '../hooks/useNuiEvent'
import Message from '../types/message'
import cx from 'classnames'
import Member from '../types/member'

type Props = {
    visible: boolean
    setVisible: (visible: boolean) => void
}

const fakeMessages: Message[] = [
    {
        image: 'https://cdn.discordapp.com/attachments/1094660235479744552/1276320714466529321/image.png?ex=66d1ab8b&is=66d05a0b&hm=53aafcbdbf310bca116f1b14866f5e6bce2434254c595ce7ef2f483c5da8fa5e&',
        name: 'Bonnie Green',
        message: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        time: '11:46',
        me: false
    },
    {
        image: 'https://cdn.discordapp.com/attachments/1094660235479744552/1276320714466529321/image.png?ex=66d1ab8b&is=66d05a0b&hm=53aafcbdbf310bca116f1b14866f5e6bce2434254c595ce7ef2f483c5da8fa5e&',
        name: 'Bonnie Green',
        message: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
        time: '13:52',
        me: true
    },
]

export default function ChatBox({ visible, setVisible }: Props) {
    const [messages, setMessages] = React.useState<Message[]>([])
    const [messageInput, setMessageInput] = React.useState('')
    const [membersCount, setMembersCount] = React.useState(1)
    const { locale } = useSelector((state: RootState) => state.localeSlice)
    const { squad, squadId } = useSelector((state: RootState) => state.globalSlice)

    useNuiEvent('updateMembers', (members: Member[]) => {
        setMembersCount(members.length)
    })

    useEffect(() => {
        if (!squadId) return
        fetchNui('getMessages').then((data: any) => {
            setMessages(data)
        }).catch((err) => {
            console.error(err)
            setMessages(fakeMessages)
        })
    }, [squadId])


    const AlwaysScrollToBottom = () => {
        const elementRef = useRef<HTMLDivElement>(null);
        useEffect(() => elementRef.current?.scrollIntoView({ behavior: 'smooth' }));
        return <div ref={elementRef} />;
      };

    useNuiEvent('sendMessage', (message: Message) => {
        setMessages([...messages, message])
    })

    const sendMessage = () => {
        if (!messageInput) return
        if (messageInput.length > 500) return
        if (messageInput.length < 1) return
        setMessageInput('')
        fetchNui('sendMessage', messageInput)
    }

    return (
        <div className={cx('animate-appearFromLeft relative flex flex-col min-w-[30vh] justify-between h-1/2 bg-menu-bg rounded-tr-lg duration-300 border-l border-white/[.05]', {
            'hidden': !visible,
            'flex': visible,
        })}>
            <div className='w-full h-16 bg-gradient-to-r from-chat-header-alpha via-danger-alpha via-50% to-chat-header flex flex-row px-4 rounded-tr-lg'>
                <div className='w-full flex flex-col justify-center items-start w-16 h-16'>
                    <p className='text-white text-lg font-bold'>{locale.squadChat.replace('{squadName}', squad.name)}
                    </p>
                    <div className='flex flex-row items-center gap-2'>
                        <div className='size-2 rounded-full bg-green-400 shadow shadow-green'></div>
                        <p className='text-white/[.4] text-xs font-bold'>{membersCount} {locale.online}</p>
                    </div>

                </div>
                <button className='flex-center items-start text-white/[.4] duration-300 hover:text-white' onClick={() => setVisible(false)}>
                    <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 1024 1024"><path fill="currentColor" d="M195.2 195.2a64 64 0 0 1 90.496 0L512 421.504L738.304 195.2a64 64 0 0 1 90.496 90.496L602.496 512L828.8 738.304a64 64 0 0 1-90.496 90.496L512 602.496L285.696 828.8a64 64 0 0 1-90.496-90.496L421.504 512L195.2 285.696a64 64 0 0 1 0-90.496" /></svg>
                </button>
            </div>
            <div className='w-full h-full flex flex-col gap-4 overflow-y-auto px-4 py-2'>
                {
                    messages.map((message, index) => (
                        <ChatBubble key={index} messageData={message} />
                    ))
                }
                <AlwaysScrollToBottom />
            </div>
            <div className='px-4'>
                <div className='border-t border-white/[.1] w-full h-12 flex flex-row items-center justify-between'>
                    <input type='text' className='w-full bg-transparent text-white text-sm font-bold outline-none' placeholder='Type a message...' onChange={(e) => setMessageInput(e.target.value)} value={messageInput}
                        onKeyPress={(e) => e.key == 'Enter' && sendMessage()}
                    />
                    <button onClick={sendMessage} disabled={messageInput.length == 0} className='flex-center items-center text-white/[.4] duration-300'>
                        <svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M2.345 2.245a1 1 0 0 1 1.102-.14l18 9a1 1 0 0 1 0 1.79l-18 9a1 1 0 0 1-1.396-1.211L4.613 13H10a1 1 0 1 0 0-2H4.613L2.05 3.316a1 1 0 0 1 .294-1.071z" clip-rule="evenodd" /></svg>
                    </button>
                </div>
            </div>
        </div>
    )
}