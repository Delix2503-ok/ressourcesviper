import { useEffect } from 'react';

type KeyHandler = (event: KeyboardEvent) => void;

function useKeyPress(targetKey: string, callback: KeyHandler) {
    // Tuş basıldığında tetiklenecek fonksiyon
    const handleKeyPress = (event: KeyboardEvent) => {
        // Eğer basılan tuş, hedef tuşsa callback'i çağır
        if (event.key === targetKey) {
            callback(event);
        }
    };

    useEffect(() => {
        // Event listener'ı ekle
        window.addEventListener('keydown', handleKeyPress);

        // Component unmount olduğunda event listener'ı kaldır
        return () => {
            window.removeEventListener('keydown', handleKeyPress);
        };
    }, [targetKey, callback]); // targetKey ve callback bağımlılıklarına dikkat et

    return;
}

export default useKeyPress;
