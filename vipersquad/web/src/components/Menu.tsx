import React from 'react'
import { VisibilityProvider } from '../providers/VisibilityProvider'
import { useSelector } from 'react-redux'
import { RootState } from '../store'

type Props = {
    children: React.ReactNode
}

export default function Menu({
    children
}: Props) {
    const { locale } = useSelector((state: RootState) => state.localeSlice)

    return (
            <div className='h-screen bg-menu-bg w-fit pt-5 flex flex-col'>
                <div className='px-6'>
                    <div className='flex flex-row justify-start items-center gap-2 '>
                        <div className='text-primary text-2xl xl:text-3xl max-w-32 font-bold uppercase'>{locale.squad}</div>
                        <div className='w-1 h-3 rounded-full bg-menu-border'></div>
                        <div className='text-menu-border text-lg md:text-xl font-bold'>{locale.members}</div>
                    </div>
                    <p className='text-menu-border max-w-48 lg:max-w-full text-sm lg:text-lg font-bold'>{locale.menuDesc}</p>
                    <div className='w-full h-[.15vh] mt-4 bg-gradient-to-r from-menu-divider from-0% via-menu-border via-30% to-menu-divider rounded-full bg-menu-border'></div>
                </div>
                {
                    children
                }
            </div>
    )
}