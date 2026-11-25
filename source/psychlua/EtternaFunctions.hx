package psychlua;

class EtternaFunctions
{
    // Coefficients for the Abramowitz and Stegun approximation of the error function.
    static inline var ERF_COEFFICIENT_A1 = 0.254829592;
    static inline var ERF_COEFFICIENT_A2 = -0.284496736;
    static inline var ERF_COEFFICIENT_A3 = 1.421413741;
    static inline var ERF_COEFFICIENT_A4 = -1.453152027;
    static inline var ERF_COEFFICIENT_A5 = 1.061405429;
    static inline var ERF_COEFFICIENT_P = 0.3275911;

    public static function erf(value:Float):Float
    {
        // Preserve the input sign, then evaluate the approximation for its absolute value.
        var signMultiplier = 1;
        if (value < 0)
            signMultiplier = -1;
        value = Math.abs(value);

        var approximationScale = 1.0 / (1.0 + ERF_COEFFICIENT_P * value);
        var approximation = 1.0 - (((((ERF_COEFFICIENT_A5 * approximationScale + ERF_COEFFICIENT_A4) * approximationScale)
            + ERF_COEFFICIENT_A3) * approximationScale + ERF_COEFFICIENT_A2) * approximationScale + ERF_COEFFICIENT_A1)
            * approximationScale * Math.exp(-value * value);

        return signMultiplier * approximation;
    }

    /**
     * Calculates the WIFE3 score for an absolute note timing error.
     * @param timingErrorMs Absolute timing error in milliseconds.
     * @param timingScale Timing scale used to derive judgement windows.
     */
    public static function wife3(timingErrorMs:Float, timingScale:Float):Float
    {
        var maximumPoints = 1.0;
        var missWeight = -1.0;
        var perfectWindowMs = 5 * timingScale;
        var maximumMissWindowMs = 180 * timingScale;
        var timingScaleExponent = 0.75;
        var zeroScoreWindowMs = 65 * Math.pow(timingScale, timingScaleExponent);
        var exponentialDeviationMs = 22.7 * Math.pow(timingScale, timingScaleExponent);

        // Timing errors inside the perfect window receive full points.
        if (timingErrorMs <= perfectWindowMs)
            return maximumPoints;
        // The near-perfect region decays smoothly toward zero points.
        else if (timingErrorMs <= zeroScoreWindowMs)
            return maximumPoints * erf((zeroScoreWindowMs - timingErrorMs) / exponentialDeviationMs);
        // The outer timing-error region decreases linearly from zero points to the miss weight.
        else if (timingErrorMs <= maximumMissWindowMs)
            return (timingErrorMs - zeroScoreWindowMs) * missWeight / (maximumMissWindowMs - zeroScoreWindowMs);
        else
            return missWeight;
    }
}
