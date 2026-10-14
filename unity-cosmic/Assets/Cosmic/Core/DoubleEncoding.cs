using System;
using System.Globalization;

namespace Cosmic.Core
{
    public static class DoubleEncoding
    {
        // Optional IEEE-754 little-endian bytes avoid serializer rounding/signed-zero loss.
        public static double Read(double fallback,string hex)
        {
            if(hex==null)return fallback;
            if(hex.Length!=16)throw new ArgumentException("Double bit representation must have 16 hexadecimal digits.");
            var bytes=new byte[8];
            for(int i=0;i<8;i++)bytes[i]=byte.Parse(hex.Substring(i*2,2),NumberStyles.HexNumber,CultureInfo.InvariantCulture);
            if(!BitConverter.IsLittleEndian)Array.Reverse(bytes);
            return BitConverter.ToDouble(bytes,0);
        }
        public static Double3 Read(double[] fallback,string[] hex)
        {
            var value=Double3.FromArray(fallback);
            if(hex==null)return value;
            if(hex.Length!=3)throw new ArgumentException("Vector bits must have three components.");
            return new Double3(Read(value.X,hex[0]),Read(value.Y,hex[1]),Read(value.Z,hex[2]));
        }
    }
}
