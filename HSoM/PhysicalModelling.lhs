%-*- mode: Latex; abbrev-mode: true; auto-fill-function: do-auto-fill -*-

%include lhs2TeX.fmt
%include myFormat.fmt

\out{
\begin{code}
-- This code was automatically generated by lhs2tex --code, from the file 
-- HSoM/Additive.lhs.  (See HSoM/MakeCode.bat.)

\end{code}
}

\chapter{Physical Modelling}
\label{ch:physical-modelling}

\section{Introduction}

...

\section{Delay Lines}

An important tool for physical modeling is the \emph{delay line}.  In
this section we will discuss the basic concepts of a delay line, the
delay line signal functions in Eutperpea, and a couple of fun examples
that do not yet involve physical modeling.

Conceptually, a delay line is fairly simple: it delays a signal by a
certain number of seconds (or, equivalently, by a certain number of
samples at some given sample rate).  Figure~\ref{fig:delay-lines}(a)
show this pictorially---if $s$ is the number of samples in the delay
line, and $r$ is the clock rate, then the delay $d$ is given by:
\[ d = s/r \]
In the case of audio, of course, $r$ will be 44.1 kHz.  So to achieve a
one-second delay, $s$ would be chosen to be 44,100.  In essence, a
delay line is a \emph{queue} or \emph{FIFO} data structure.

\begin{figure}
Unit delay line:
\begin{code}
init ::  Clock c => 
         Double -> SigFun c Double Double
\end{code}

Fixed-length delay line, initialized with a table:
\begin{code}
delayLineT ::  Clock c => 
               Int -> Table -> SigFun c Double Double
\end{code}

Fixed-length delay line, initialized with zeros:
\begin{code}
delayLine ::  Clock c => 
              Double -> SigFun c Double Double
\end{code}

Delay line with variable tap:
\begin{code}
delayLine1 ::  Clock c => 
               Double -> SigFun c (Double, Double) Double
\end{code}
\caption{Euterpea's Delay Lines}
\label{fig:delay-line-types}
\end{figure}

In Euterpea there is a family of delay lines whose type signatures are
given in Figure~\ref{fig:delay-line-types}.  Their behaviors can be
described as follows:
\begin{itemize}
\item
|init x| is a delay line with one element, which is initalized to |x|.
\item
|delayLineT s tab| is a delay line whose length is $s$ and whose
contents are initialized to the values in the table |tab| (presumably
of length $s$).
\item
|delayLine d| is a delay line whose length achieves a delay of $d$
seconds.
\item
|delayLine1 d| is a ``tapped delay line'' whose length achieves a
maximum delay of $d$ seconds, but whose actual output is a ``tap''
that results in a delay of somewhere between 0 and $d$ seconds.  The
tap is controlled dynamically.  For example, in:
\begin{spec}
...
out <- delayLine1 d -< (s,t)
...
\end{spec}
|s| is the input signal, and |t| is the tap delay, which may vary
between 0 and |d|.
\end{itemize}

Before using delay lines for physical modelling, we will explore a few
simple application that should give the reader a good sense of how
they work.

\begin{figure}[hbtp]
\centering
\includegraphics[height=7.5in]{pics/DelayLines.eps}
\caption{Delay Line Examples}
\label{fig:delay-line-examples}
\end{figure}

\subsection{Simulating an Oscillator}

Let's contrast a delay line to the oscillators introduced in
Chapter~\ref{ch:sigfuns} that are initialized with a table (like
|osc|).  These oscillators cycle repetitively through a given table at
a variable rate.  Using |delayT|, a delay-line can also be initialized
as a table, but it is processed at a fixed rate (i.e.\ the clock
rate)---at each step, one value goes in, and one goes out.

Nevertheless, we can simulate an oscillator by initializing the delay
line with one cycle of a sine wave, and ``feeding back'' the output to
the input, as shown in Figure~\ref{fig:delay-line-examples}a.  At the
standard audio sample rate, if the table size is $s$, then it takes
$s/44,100$ seconds to output one cycle, and therefore the resulting
frequency is the reciprocol of that:
\[ f = 44,100 / s \]

There is one problem, however: when coding this idea in Haskell, we'd
like to write something like:
\begin{spec}
...
x <- delayLineT s table -< x
...
\end{spec}
However, arrow syntax in its standard form does not allow recursion!
Fortunately, arrow syntax supports a keyword |rec| that allows us to specify
where recursion takes place.  For example to generate a tone of 441 Hz
we need a table size of 44,100/441 = 100, leading to:
%% make analogy to let and letrec in Scheme?
\begin{code}
sineTable441 :: Table
sineTable441 = tableSinesN 100 [1]

s441 :: AudSF () Double
s441 = proc () -> do
         rec s <- delayLineT 100 sineTable441 -< s
         outA -< s

ts441 = outFile "s441.wav" 5 s441
\end{code}

\syn{Say more about the |rec| keyword.}

\subsection{Echo Effect}

Perhaps a more obvious use of a delay line is to simply delay a signal!
But to make this more exciting, let's go one step further and
\emph{echo} the signal, using feedback.  To prevent the signal from
echoing forever, let's decay it a bit each time it is fed back.  A
diagram showing this strategy is shown in
Figure~\ref{fig:delay-line-examples}b, and the resulting code is:
\begin{code}
echo :: AudSF Double Double
echo = proc s -> do
         rec fb  <- delayLine 0.5 -< s + 0.7*fb
         outA -< fb/3
\end{code}
Here the delay time is 0.5 seconds, and the decay rate is 0.7.

[test code?]

\subsection{Modular Vibrato}

Recall that we previously defined a tremolo signal function that could
take an arbitrary signal and add tremolo.  This is because tremolo
simply modulates the amplitude of a signal, which could be
anything---music, speech, whatever---and can be done after that sound
is generated.  So we could define a function:
\begin{spec}
tremolo :: Rate -> Depth -> AudSF Double Double
\end{spec}
to achieve the result we want.

Can we do the same for vibrato?  In the version of vibrato we defined
previously (see Section~\ref{}), we used frequency modulation---but
that involved modulating the actual frequency of a specific
oscillator, \emph{not} the output of the oscillator that generated a
sine wave of that frequency.  So using that technique, at least, it
doesn't seem possible to define a function such as:
\begin{spec}
vibrato :: Rate -> Depth -> AudSF Double Double
\end{spec}
that would achieve our needs.  Indeed, if we were using additive
synthesis, one might imagine having to add vibrato to every sine wave
that makes up the result.  Not only is this a daunting task, but, in
effect, we would lose modularity!

But in fact we can define a ``modular'' vibrato using a delay line
with a variable tap.  The idea is this: Send a signal into a tapped
delay line, adjust the initial tap to the center of that delay line,
and then move it back and forth sinusoidally at a certain rate to
control the frequency of the vibrato, and move it a certain distance
(with a maximum of one-half the delay line's maximum delay) to achieve
the depth.  This idea is shown pictorially in
Figure~\ref{fig:delay-line-examples}c, and the code is given below:
\begin{code}
vibrato :: Rate -> Depth -> AudSF Double Double
modVib :: AudSF Double Double
modVib rate depth =
  proc sin -> do
    vib   <- osc sineTable 0  -< rate
    sout  <- delayLine1 0.2   -< (sin,0.1+0.005*vib)
    outA -< sout

tModVib = outFile "modvib.wav" 6 $$
                  constA 440 >>> osc sineTable 0 >>> vibrato 5 0.005
\end{code} -- 

[discuss problem with ``noisy'' output, and with initial delay]

\section{Karplus-Strong Algorithm}

Now that we know how delay lines work, let's look at their use in
physical modeling.  The \emph{Karplus-Strong Algorithm}
\cite{Karplus-Strong83} was one of the first algorithms classified as
``physical modeling.''  It's a good model for synthesizing plucked
strings and drum-like sounds.  The basic idea is to use a recursive
delay line to feed back a signal onto itself, thus simulating the
standing wave modes discussed in Section~\ref{sec:resonance}.  The
result is affected by the initial values in the delay line, the length
of the delay line, and any processing in the feedback loop.  A diagram
that depicts this algorithm is shown in
Figure~\ref{fig:karplus-strong}(a).

\begin{figure}
\centering
\includegraphics[height=7.5in]{pics/KarplusStrong.eps}
\caption{Karplus-Strong and Waveguides}
\label{fig:karplus-strong}
\end{figure}

\subsection{Physical Model of a Flute}
\label{sec:flute-model}

Figure~\ref{fig:flute-model} shows a physical model of a flute, based
on the model of a ``slide flute'' proposed by Perry Cook
in~\cite{Cook2002}.  Although described as a slide flute, it sounds
remarkably similar a regular flute.  Note that the lower right part of
diagram looks just like the feedback loop in the Karplus-Strong
algorithm.  The rest of the diagram is intended to model the breath,
including vibrato, which drives a ``pitched'' embouchure that in turn
drives the flute bore.

\begin{figure}
\centering
\includegraphics[height=7in]{pics/FluteDiagram.eps}
\caption{A Physical Model of a Flute}
\label{fig:flute-model}
\end{figure}

The Euterpea code for this model is essentially a direct translation
of the diagram, with details of the envelopes added in, and is shown
in Figure~\ref{fig:flute-code}.  Some useful test cases are:
\begin{code}
f0  = flute 3 0.35 440 0.93 0.02 -- average breath
f1  = flute 3 0.35 440 0.83 0.05 -- weak breath, soft note
f2  = flute 3 0.35 440 0.53 0.04 -- very weak breath, no note
\end{code}

\begin{figure}
\cbox{
\begin{code}
flute ::  Time -> Double -> Double -> Double -> Double 
          -> AudSF () Double
flute dur amp fqc press breath = 
  proc () -> do
    env1   <- envLineSeg  [0, 1.1*press, press, press, 0] 
                          [0.06, 0.2, dur-0.16, 0.02]  -< ()
    env2   <- envLineSeg  [0, 1, 1, 0] 
                          [0.01, dur-0.02, 0.01]       -< ()
    envib  <- envLineSeg  [0, 0, 1, 1] 
                          [0.5, 0.5, dur-1]            -< ()
    flow   <- noiseWhite 42    -< ()
    vib    <- osc sineTable 0  -< 5
    let  emb = breath*flow*env1 + env1 + vib*0.1*envib
    rec  flute  <- delayLine (1/fqc)    -< out
         x      <- delayLine (1/fqc/2)  -< emb + flute*0.4
         out    <- filterLowPassBW -< (x-x*x*x + flute*0.4, 2000)
    outA -< out*amp*env2

sineTable :: Table
sineTable = tableSinesN 4096 [1]
\end{code} }
\caption{Euterpea Program for Flute Model}
\label{fig:flute-code}
\end{figure}

\section{Waveguide Synthesis}

The Karplus-Strong algorithm can be generalized to a more accurate
model of the transmission of sound up and down a medium, whether it be
a string, the air in a chamber, the surface of a drum, the metal plate
of a xylophone, and so on.  This more accurate model is called a
\emph{waveguide}, and, mathematically, can be seen as a discrete model
of d'Alembert's solution to the \emph{one-dimensional wave equation},
which captures the superposition of a right-going wave and a
left-going wave, as we have discussed earlier in
Section~\ref{sec:resonance}.  In its simplest form, we can express the
value of a wave at position $m$ and time $n$ as:
\[ y(m,n) = y^{+}(m-n) + y^{-}(m+n) \]
where $y^{+}$ is the right-going wave and $y^{-}$ is the left-going
wave.  Intuitively, the value of $y$ at point $m$ and time $n$ is the
sum of two delayed copies of its traveling waves.  As discusses before,
these traveling waves will reflect at boundaries such as the fixed
ends of a string or the open or closed ends of tubes.

What distinguishes this model from the simpler Karplus-Strong model is
that it captures waves traveling in \emph{both} directions---and to
realize that, we need a closed loop of delay lines.  But even with
that generalization, the equation above assumes a \emph{lossless}
system, and does not account for interactions \emph{between} the left-
and right-traveling waves.  The former quantity is often called the
\emph{gain}, and the latter the \emph{reflection coefficient}.  We
have discussed previously the notion that waves are reflected at the
ends of a string, a tube, etc., but in general some
interaction/reflection between the left- and right-traveling waves can
happen anywere.  This more general model is shown diagramatically in
Figure~\ref{fig:karplus-strong}(c), where $g$ is the gain, and $r$ is
the reflection coefficient.

Figure~\ref{fig:karplus-strong}(b) shows a sequence of waveguides
``wired together'' to allow for the possibility that the gain and
reflection characteristics are different at different points along the
medium.  The ``termination'' boxes can be thought of as special
waveguides that capture the effect of reflection at the end of a
string, tube, etc.

\subsection{Waveguides in Euterpea}

A simple waveguide with looping delay lines and gain factors, but that
ignores reflection, is shown below:
\begin{code}
waveguide :: Double -> Double -> Double ->
              AudSF (Double,Double) (Double,Double)
waveguide del ga gb = proc (ain,bin) -> do
  rec bout <- delayLine del -< bin - ga * aout
      aout <- delayLine del -< ain - gb * bout
  outA -< (aout,bout)
\end{code}
Here |ga| and |gb| are the gains, and |del| is the delay time of one
delay line.

This waveguide is good enough for the examples studied in this book,
in that we assume no reflections occur along the waveguide, and that
reflections at the end-points can be expressed manually with suitable
feedback.  Similarly, any filtering or output processing can be
expressed manually.

\subsection{A Pragmatic Issue}

In a circuit with feedback, DC (``direct current'') offsets can
accumulate, resulting in clipping.  The DC offset can be ``blocked''
using a special high-pass filter whose cutoff frequency is infrasonic.
This filter can be captured by the difference equation:

\[ y[n] = x[n] - x[n-1] + a * y[n-1] \]

Where $x[n]$ and $y[n]$ are the input and output, respectively, at the
current time $n$, and $a$ is called the gain factor.  If we think of
the indexing of $n$ versus $n-1$ as a one unit delay, we can view the
equation above as the diagram shown in
Figure~\ref{fig:dc-blocking-diagram}, where $z^{-1}$ is the
mathematical notation for a 1-unit delay.\footnote{This representation
  is called the \emph{Z transform} of a signal.}

If you recall from Section\ref{sec:euterpea-filters}, the one-unit
delay operator in Euterpea is called |init|.  With that in mind, it is
easy to write a Euterpea program for a DC blocking filter, as shown in
Figure~\ref{fig:dc-blocking-code}.  The transfer function
corresponding to this filter for different values of |a| is shown in
Figure~\ref{fig:dc-blocking-transfer}.  In practice, a value of 0.99
for |a| works well.

\begin{figure}
\begin{code}
dcBlock :: Double -> AudSF Double Double
dcBlock a = proc xn -> do
  rec  let yn = xn - xn_1 + a * yn_1
       xn_1  <- init 0 -< xn
       yn_1  <- init 0 -< yn
  outA -< yn
\end{code}
\caption{DC Blocking Filter in Euterpea}
\label{fig:dc-blocking-code}
\end{figure}

\begin{figure}
\centering
\includegraphics[height=7.5in]{pics/DCBlock.eps}
\caption{Transfer Function for DC Blocker}
\label{fig:dc-blocking-transfer}
\end{figure}
