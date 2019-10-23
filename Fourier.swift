import AVFoundation
import Accelerate

//let f: Float = 96000 // sampling frequency of song

struct FourierOutput {
    var realComp: [Float]
    var imagComp: [Float]
}

// do a fast fourier transform over a range of indices in audio data
func FFT(signal: [Float], start_i: Int, frames: Int) -> FourierOutput {
    let n = vDSP_Length(frames) // 1598 frames = 32064000 frames / (60.075 renders * 334 sec)
    // convert to interleaved complex data
    let observed: [DSPComplex] = stride(from: start_i, to: Int(n) + start_i, by: 2).map {
        return DSPComplex(real: signal[$0],
                          imag: signal[$0.advanced(by: 1)])
    }
    let halfN = Int(n / 2)
    
    var forwardInputReal = [Float](repeating: 0, count: halfN)
    var forwardInputImag = [Float](repeating: 0, count: halfN)
    
    var forwardInput = DSPSplitComplex(realp: &forwardInputReal,
                                       imagp: &forwardInputImag)
    // split complex vector
    vDSP_ctoz(observed, 2,
              &forwardInput, 1,
              vDSP_Length(halfN))
    
    let log2n = vDSP_Length(log2(Float(n)))
    // create setup object
    guard let fftSetUp = vDSP_create_fftsetup(
        log2n,
        FFTRadix(kFFTRadix2)) else {
            fatalError("Can't create FFT setup.")
    }
    
    var forwardOutputReal = [Float](repeating: 0, count: halfN) // will contain DC components
    var forwardOutputImag = [Float](repeating: 0, count: halfN) // will contain Nyquist components
    var forwardOutput = DSPSplitComplex(realp: &forwardOutputReal,
                                        imagp: &forwardOutputImag)
    // do out-of-place FFT
    vDSP_fft_zrop(fftSetUp,
                  &forwardInput, 1,
                  &forwardOutput, 1,
                  log2n,
                  FFTDirection(kFFTDirection_Forward))
    // destroy setup object
    do { // defer
        vDSP_destroy_fftsetup(fftSetUp)
    }
    return FourierOutput(realComp: forwardOutputReal, imagComp: forwardOutputImag)
}

// returns lower bound index in the fourier series with n = 1598 which represents
// a given frequency
func fSeriesIndexOf(fs: [Float], freqOfInd: Float, frames: Int, f: Float) -> Int {
    let df = 1/Float(frames)*f
    return Int(freqOfInd/df)
}

func filterByFreqRange(fs: [Float], f1: Float, f2: Float, frames: Int, f: Float) -> Float {
    let start_i = fSeriesIndexOf(fs: fs, freqOfInd: f1, frames: frames, f: f)
    let end_i = fSeriesIndexOf(fs: fs, freqOfInd: f2, frames: frames, f: f)
    var sum: Float = 0
    for i in start_i...end_i {
        sum += abs(fs[i])
    }
    return sum
}

func getHeavyBass(fs: [Float], frames: Int, f: Float) -> Float {
    return filterByFreqRange(fs: fs, f1: 0, f2: 100, frames: frames, f: f)
}

func getSnare(fs: [Float], frames: Int, f: Float) -> Float {
    return filterByFreqRange(fs: fs, f1: 180, f2: 250, frames: frames, f: f)
}

func getHighs(fs: [Float], frames: Int, f: Float) -> Float {
    return filterByFreqRange(fs: fs, f1: 5000, f2: 20000, frames: frames, f: f)
}

func getGuitar(fs: [Float], frames: Int, f: Float) -> Float {
    return filterByFreqRange(fs: fs, f1: 80, f2: 1200, frames: frames, f: f)
}
