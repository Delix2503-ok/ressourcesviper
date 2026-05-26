import React, { ReactEventHandler, useEffect, useState } from 'react'
import cx from 'classnames'
import { useNuiEvent } from '../hooks/useNuiEvent'

const fakeMembers = [
    {
        name: 'John Doe',
        image: 'https://i.pravatar.cc/150?img=1',
        health: 100,
        armor: 100,
    },
    {
        name: 'Jane Doe',
        image: 'https://i.pravatar.cc/150?img=2',
        health: 100,
        armor: 100,
    },
    {
        name: 'John Smith',
        image: 'https://i.pravatar.cc/150?img=3',
        health: 100,
        armor: 100,
    },
    {
        name: 'Jane Smith',
        image: 'https://i.pravatar.cc/150?img=4',
        health: 100,
        armor: 100,
    },
]

type HudProps = {
    align?: 'left' | 'right'
    memberData: {
        name: string
        image: string
        health: number
        armor: number
    }
}

// const HudMember = ({
//     align = 'center',
//     memberData
// }: HudProps) => {
//     return (
//         <div className={cx('flex text-white/[.4] items-center gap-2', {
//             "flex-col": align == "center",
//             "flex-row": align != "center"
//         })}>
//             {align == "right" && <div className='flex flex-col items-start'>
//                 <p className='text-white text-lg font-bold'>{memberData.name}</p>
//             </div>}
//             <div className='size-16 rounded-full border-2 border-[#ff2f2f]'>
//                 <img src={memberData.image} className='w-full h -full rounded-full' />
//             </div>
//             {align != "right" && <div className='flex flex-col items-start'>
//                 <p className='text-white text-lg font-bold'>{memberData.name}</p>
//             </div>}
//         </div>
//     )
// }


const HudMember = ({
    align = 'left',
    memberData
}: HudProps) => {
    return (
        <>
            {align == "left" &&
                <div className='flex w-[15.104vw] h-[1.25vw] mb-2 bg-hud-bg-alpha'>
                    <img className='w-[1.25vw] h-[1.25vw] object-cover' src={memberData.image} alt="" />
                    <div className='flex flex-col justify-between w-full h-full'>
                        <div className='w-full h-[93%] flex'>
                            <div className='flex items-center justify-center w-[15%] h-full bg-health-label'>
                                <p className='text-[0.677vw] font-bold text-white'>{memberData.health}</p>
                            </div>
                            <div className='relative w-[85%] h-full bg-health-bar'>
                                <h1 className='absolute left-2 text-[0.760vw] font-bold text-white'>{memberData.name}</h1>
                            </div>
                        </div>
                        <div className={`w-[${memberData.armor}%] h-[7%] bg-armor-bar`}></div>
                    </div>
                </div>
            }
            {align == "right" &&
                <div className='flex flex-row-reverse w-[15.104vw] h-[1.25vw] mb-2 bg-hud-bg-alpha'>
                    <img className='w-[1.25vw] h-[1.25vw] object-cover' src={memberData.image} alt="" />
                    <div className='flex flex-col justify-between items-end w-full h-full'>
                        <div className='w-full h-[93%] flex flex-row-reverse'>
                            <div className='flex items-center justify-center w-[15%] h-full bg-health-label'>
                                <p className='text-[0.677vw] font-bold text-white'>{memberData.health}</p>
                            </div>
                            <div className='relative w-[85%] h-full bg-health-bar'>
                                <h1 className='absolute right-2 text-[0.760vw] font-bold text-white'>{memberData.name}</h1>
                            </div>
                        </div>
                        <div className={`w-[${memberData.armor}%] h-[7%] bg-armor-bar`}></div>
                    </div>
                </div>
            }
        </>

    )
}

export default function Hud({
    align = 'left'
}: {
    align: 'left' | 'right'
}) {
    const [members, setMembers] = React.useState([])

    useNuiEvent('setHudMembers', (members: any) => {
        setMembers(members)
    })

    const hudPosition = localStorage.getItem('hudPosition') ? JSON.parse(localStorage.getItem('hudPosition')!) : { x: 0, y: 0 }

    const [position, setPosition] = useState(hudPosition);
    const [dragging, setDragging] = useState(false);
    const [relPosition, setRelPosition] = useState({ x: 0, y: 0 });

    // Mouse down olduğunda sürüklemeye başla
    const handleMouseDown = (e: any) => {
        setDragging(true);
        // Div'in tıklanan noktasının konumunu hesaplıyoruz
        setRelPosition({
            x: e.clientX - position.x,
            y: e.clientY - position.y,
        });
    };

    // Mouse hareket ettikçe div'i sürükle
    const handleMouseMove = (e: any) => {
        if (dragging) {
            // Div'in pozisyonunu güncelle
            setPosition({
                x: e.clientX - relPosition.x,
                y: e.clientY - relPosition.y,
            });
        }
    };

    // Mouse'u bıraktığımızda sürüklemeyi durdur
    const handleMouseUp = () => {
        setDragging(false);
        localStorage.setItem('hudPosition', JSON.stringify(position));
    };

    return (
        <div className='absolute gap-2 h-fit px-2 max-w-fit' onMouseDown={handleMouseDown}
            onMouseMove={handleMouseMove}
            onMouseUp={handleMouseUp}
            style={{
                right: `${-position.x}px`,
                bottom: `${-position.y}px`,
                cursor: dragging ? 'grabbing' : 'grab',
            }}>
            {members.map((member, index) => (
                <HudMember key={index} memberData={member} align={align} />
            ))}
        </div>

    )
}