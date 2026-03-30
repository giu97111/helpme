import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Shield, AlertTriangle, MapPin, User, Bell, X, Phone, Navigation, ArrowLeft } from 'lucide-react';

type AppState = 'onboarding' | 'idle' | 'countdown' | 'active' | 'receiving' | 'navigating';

export default function App() {
  const [appState, setAppState] = useState<AppState>('onboarding');
  const [name, setName] = useState('');
  const [location, setLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [countdown, setCountdown] = useState(3);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Request location
  const requestLocation = () => {
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setLocation({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          });
          setAppState('idle');
        },
        (error) => {
          console.error('Error getting location:', error);
          // Proceed anyway for the demo
          setAppState('idle');
        }
      );
    } else {
      setAppState('idle');
    }
  };

  // Handle SOS Button Hold
  const startSOS = () => {
    setAppState('countdown');
    setCountdown(3);
  };

  useEffect(() => {
    if (appState === 'countdown') {
      timerRef.current = setInterval(() => {
        setCountdown((prev) => {
          if (prev <= 1) {
            clearInterval(timerRef.current!);
            setAppState('active');
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } else if (timerRef.current) {
      clearInterval(timerRef.current);
    }

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [appState]);

  const cancelSOS = () => {
    setAppState('idle');
  };

  // Simulate receiving an alert after 15 seconds of being idle (just for demo purposes)
  useEffect(() => {
    let timeout: NodeJS.Timeout;
    if (appState === 'idle') {
      timeout = setTimeout(() => {
        setAppState('receiving');
      }, 15000);
    }
    return () => clearTimeout(timeout);
  }, [appState]);

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-50 font-sans overflow-hidden selection:bg-red-500/30">
      <AnimatePresence mode="wait">
        {/* ONBOARDING STATE */}
        {appState === 'onboarding' && (
          <motion.div
            key="onboarding"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="flex flex-col items-center justify-center min-h-screen p-6 max-w-md mx-auto"
          >
            <div className="w-20 h-20 bg-red-500/10 rounded-full flex items-center justify-center mb-8">
              <Shield className="w-10 h-10 text-red-500" />
            </div>
            <h1 className="text-3xl font-bold mb-2 text-center">Scudo</h1>
            <p className="text-zinc-400 text-center mb-12">
              La tua rete di sicurezza personale. Avvisa chi ti sta intorno in caso di pericolo.
            </p>

            <div className="w-full space-y-4">
              <input
                type="text"
                placeholder="Il tuo nome"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-4 focus:outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-colors"
              />
              <button
                onClick={requestLocation}
                disabled={!name.trim()}
                className="w-full bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:hover:bg-red-600 text-white font-semibold rounded-xl px-4 py-4 transition-colors flex items-center justify-center gap-2"
              >
                <MapPin className="w-5 h-5" />
                Consenti Posizione e Inizia
              </button>
            </div>
          </motion.div>
        )}

        {/* IDLE STATE */}
        {appState === 'idle' && (
          <motion.div
            key="idle"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="flex flex-col min-h-screen max-w-md mx-auto relative"
          >
            {/* Header */}
            <header className="flex items-center justify-between p-6 z-10">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-zinc-900 rounded-full flex items-center justify-center">
                  <User className="w-5 h-5 text-zinc-400" />
                </div>
                <div>
                  <p className="text-sm font-medium">{name || 'Utente'}</p>
                  <p className="text-xs text-green-400 flex items-center gap-1">
                    <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                    Rete attiva
                  </p>
                </div>
              </div>
              <button className="w-10 h-10 bg-zinc-900 rounded-full flex items-center justify-center relative">
                <Bell className="w-5 h-5 text-zinc-400" />
                <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full" />
              </button>
            </header>

            {/* Radar / Map Area */}
            <div className="flex-1 flex flex-col items-center justify-center relative z-0 mt-[-80px]">
              {/* Radar Rings */}
              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                {[1, 2, 3].map((i) => (
                  <motion.div
                    key={i}
                    className="absolute rounded-full border border-red-500/20"
                    style={{ width: i * 120, height: i * 120 }}
                    animate={{
                      scale: [1, 1.2, 1],
                      opacity: [0.1, 0.3, 0.1],
                    }}
                    transition={{
                      duration: 4,
                      repeat: Infinity,
                      delay: i * 0.5,
                      ease: "easeInOut"
                    }}
                  />
                ))}
              </div>
              
              <div className="text-center z-10 bg-zinc-950/80 backdrop-blur-md px-6 py-3 rounded-full border border-zinc-800">
                <p className="text-sm text-zinc-300 font-medium flex items-center gap-2">
                  <MapPin className="w-4 h-4 text-red-500" />
                  14 persone nel raggio di 500m
                </p>
              </div>
            </div>

            {/* SOS Button Area */}
            <div className="p-8 pb-12 flex flex-col items-center z-10">
              <p className="text-zinc-500 text-sm mb-6 text-center">
                Tocca il pulsante in caso di pericolo per avvisare chi ti è vicino.
              </p>
              
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={startSOS}
                className="relative w-48 h-48 rounded-full bg-gradient-to-b from-red-500 to-red-700 shadow-[0_0_60px_rgba(220,38,38,0.4)] flex flex-col items-center justify-center gap-2 border-4 border-zinc-950 outline outline-2 outline-red-500/50"
              >
                <AlertTriangle className="w-12 h-12 text-white" />
                <span className="text-3xl font-black tracking-widest text-white">SOS</span>
              </motion.button>
            </div>
          </motion.div>
        )}

        {/* COUNTDOWN STATE */}
        {appState === 'countdown' && (
          <motion.div
            key="countdown"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 1.1 }}
            className="flex flex-col items-center justify-center min-h-screen p-6 max-w-md mx-auto bg-red-950"
          >
            <motion.div
              animate={{ scale: [1, 1.1, 1] }}
              transition={{ duration: 1, repeat: Infinity }}
              className="text-9xl font-black text-red-500 mb-8"
            >
              {countdown}
            </motion.div>
            <h2 className="text-2xl font-bold text-white mb-2 text-center">Invio allarme in corso...</h2>
            <p className="text-red-200 text-center mb-12">
              Tutti gli utenti nelle vicinanze riceveranno la tua posizione.
            </p>

            <button
              onClick={cancelSOS}
              className="w-full max-w-xs bg-zinc-900 hover:bg-zinc-800 text-white font-bold rounded-full px-8 py-5 transition-colors border border-zinc-700 flex items-center justify-center gap-2"
            >
              <X className="w-6 h-6" />
              ANNULLA ALLARME
            </button>
          </motion.div>
        )}

        {/* ACTIVE ALARM STATE */}
        {appState === 'active' && (
          <motion.div
            key="active"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="flex flex-col items-center justify-center min-h-screen p-6 max-w-md mx-auto bg-red-600"
          >
            <motion.div
              animate={{ opacity: [1, 0.5, 1] }}
              transition={{ duration: 1, repeat: Infinity }}
              className="w-24 h-24 bg-white rounded-full flex items-center justify-center mb-8 shadow-2xl"
            >
              <AlertTriangle className="w-12 h-12 text-red-600" />
            </motion.div>
            
            <h2 className="text-3xl font-black text-white mb-2 text-center tracking-wide">ALLARME INVIATO</h2>
            <p className="text-red-100 text-center mb-12 font-medium">
              14 persone nelle vicinanze sono state avvisate e stanno vedendo la tua posizione.
            </p>

            <div className="w-full space-y-4">
              <button className="w-full bg-white text-red-600 font-bold rounded-xl px-4 py-4 transition-colors flex items-center justify-center gap-2 shadow-lg">
                <Phone className="w-5 h-5" />
                Chiama il 112 (Forze dell'Ordine)
              </button>
              
              <button
                onClick={() => setAppState('idle')}
                className="w-full bg-red-800 hover:bg-red-900 text-white font-semibold rounded-xl px-4 py-4 transition-colors flex items-center justify-center gap-2"
              >
                Segnala come "Sono al sicuro"
              </button>
            </div>
          </motion.div>
        )}

        {/* RECEIVING ALERT STATE (Simulated) */}
        {appState === 'receiving' && (
          <motion.div
            key="receiving"
            initial={{ opacity: 0, y: 50 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="flex flex-col min-h-screen max-w-md mx-auto bg-zinc-950 relative"
          >
            {/* Flashing background effect */}
            <motion.div
              animate={{ opacity: [0, 0.2, 0] }}
              transition={{ duration: 1, repeat: Infinity }}
              className="absolute inset-0 bg-red-600 pointer-events-none"
            />
            
            <div className="flex-1 flex flex-col p-6 z-10">
              <div className="bg-red-600 rounded-3xl p-6 shadow-2xl mt-8 border border-red-500">
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center shrink-0 animate-pulse">
                    <AlertTriangle className="w-8 h-8 text-red-600" />
                  </div>
                  <div>
                    <h2 className="text-2xl font-black text-white leading-tight">RICHIESTA DI AIUTO</h2>
                    <p className="text-red-200 font-medium">A 300 metri da te</p>
                  </div>
                </div>
                
                <div className="bg-red-950/50 rounded-xl p-4 mb-6">
                  <p className="text-white font-medium mb-1">Giulia Rossi</p>
                  <p className="text-red-200 text-sm">Ha attivato l'allarme di emergenza. Potrebbe essere in pericolo.</p>
                </div>

                <div className="space-y-3">
                  <button 
                    onClick={() => setAppState('navigating')}
                    className="w-full bg-white text-red-600 font-bold rounded-xl px-4 py-4 transition-colors flex items-center justify-center gap-2"
                  >
                    <Navigation className="w-5 h-5" />
                    Ottieni Indicazioni
                  </button>
                  <button className="w-full bg-red-700 hover:bg-red-800 text-white font-semibold rounded-xl px-4 py-4 transition-colors flex items-center justify-center gap-2">
                    <Phone className="w-5 h-5" />
                    Chiama 112
                  </button>
                </div>
              </div>
              
              <button
                onClick={() => setAppState('idle')}
                className="mt-auto mb-8 w-full text-zinc-500 hover:text-zinc-300 font-medium py-4 transition-colors"
              >
                Ignora (Non sono nelle condizioni di aiutare)
              </button>
            </div>
          </motion.div>
        )}

        {/* NAVIGATING (MAP) STATE */}
        {appState === 'navigating' && (
          <motion.div
            key="navigating"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, y: 50 }}
            className="flex flex-col min-h-screen max-w-md mx-auto bg-zinc-950 relative overflow-hidden"
          >
            {/* Fake Map Background using CSS Grid */}
            <div 
              className="absolute inset-0 z-0 opacity-20" 
              style={{
                backgroundImage: 'linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)',
                backgroundSize: '30px 30px',
                backgroundPosition: 'center center'
              }}
            />

            {/* Map Elements (User and Target) */}
            <div className="absolute inset-0 z-0 flex items-center justify-center pointer-events-none">
               {/* Route Line */}
               <svg className="absolute w-full h-full" viewBox="0 0 100 100" preserveAspectRatio="none">
                 <motion.path 
                   d="M 50 75 Q 20 50 50 25" 
                   fill="transparent" 
                   stroke="#ef4444" 
                   strokeWidth="1.5" 
                   strokeDasharray="3 3"
                   initial={{ pathLength: 0 }}
                   animate={{ pathLength: 1 }}
                   transition={{ duration: 1.5, ease: "easeInOut" }}
                 />
               </svg>
               
               {/* User Dot (You) */}
               <div className="absolute top-[75%] left-[50%] -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
                 <div className="w-5 h-5 bg-blue-500 rounded-full border-4 border-zinc-950 shadow-[0_0_15px_rgba(59,130,246,0.6)] z-10 relative" />
                 <span className="text-[10px] font-bold mt-1 text-blue-400 bg-zinc-950/80 px-2 py-0.5 rounded-full">TU</span>
               </div>
               
               {/* Target Dot (Giulia) */}
               <div className="absolute top-[25%] left-[50%] -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
                 <div className="w-8 h-8 bg-red-500 rounded-full border-4 border-zinc-950 shadow-[0_0_20px_rgba(239,68,68,0.8)] z-10 relative flex items-center justify-center animate-bounce">
                   <div className="w-2 h-2 bg-white rounded-full" />
                 </div>
                 {/* Ping animation */}
                 <div className="absolute top-0 left-0 w-8 h-8 bg-red-500 rounded-full animate-ping opacity-75" />
                 <span className="text-[10px] font-bold mt-1 text-red-400 bg-zinc-950/80 px-2 py-0.5 rounded-full">GIULIA</span>
               </div>
            </div>

            {/* Top Bar */}
            <div className="z-10 bg-zinc-900/90 backdrop-blur-md p-4 border-b border-zinc-800 flex items-center gap-4">
              <button 
                onClick={() => setAppState('receiving')} 
                className="w-10 h-10 bg-zinc-800 hover:bg-zinc-700 rounded-full flex items-center justify-center transition-colors shrink-0"
              >
                <ArrowLeft className="w-5 h-5 text-zinc-300" />
              </button>
              <div>
                <h2 className="text-lg font-bold text-white leading-tight">Raggiungi Giulia</h2>
                <p className="text-red-400 font-medium text-sm">300 metri • 2 min a piedi</p>
              </div>
            </div>

            {/* Bottom Actions */}
            <div className="mt-auto z-10 bg-zinc-900/90 backdrop-blur-md p-6 border-t border-zinc-800 rounded-t-3xl">
              <div className="flex gap-3 mb-4">
                <button className="flex-1 bg-red-600 hover:bg-red-700 text-white font-bold rounded-xl py-4 flex items-center justify-center gap-2 transition-colors shadow-lg shadow-red-900/20">
                  <Phone className="w-5 h-5" />
                  Chiama 112
                </button>
              </div>
              <button 
                onClick={() => setAppState('idle')} 
                className="w-full bg-zinc-800 hover:bg-zinc-700 text-white font-semibold rounded-xl py-4 transition-colors"
              >
                Termina Navigazione
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
