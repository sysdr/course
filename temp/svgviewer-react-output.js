import * as React from "react";
import Svg, {
  Defs,
  Rect,
  G,
  Circle,
  Text,
  Path,
  Polygon,
  Line,
} from "react-native-svg";
/* SVGR has dropped some elements not supported by react-native-svg: style, animate */
const SVGComponent = (props) => (
  <Svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" {...props}>
    <Defs></Defs>
    <Rect
      width={600}
      height={600}
      rx={20}
      fill="#f8f9fa"
      filter="drop-shadow(0 4px 6px rgba(0,0,0,0.1))"
    />
    <G transform="translate(330, 250)">
      <G transform="translate(-300, -180)">
        <Circle cx={0} cy={0} r={20} fill="#4a5568" className="pulse" />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={12}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"USER"}
        </Text>
        <Text
          x={0}
          y={35}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="#2d3748"
        >
          {"REQUESTS"}
        </Text>
        <Path
          d="M 20,0 L 100,0"
          stroke="#4299e1"
          strokeWidth={3}
          fill="none"
          className="flow-line"
        />
      </G>
      <G transform="translate(-180, -180)" className="scale">
        <Rect
          x={-40}
          y={-20}
          width={80}
          height={40}
          rx={5}
          fill="#2c5282"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"API GATEWAY"}
        </Text>
        <Path
          d="M 40,0 L 80,0"
          stroke="#4299e1"
          strokeWidth={3}
          fill="none"
          className="flow-line"
        />
      </G>
      <G transform="translate(-60, -180)">
        <Polygon
          points="-30,-20 30,-20 40,0 30,20 -30,20 -40,0"
          fill="#90cdf4"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="#2d3748"
        >
          {"LOAD BALANCER"}
        </Text>
        <Path
          d="M 0,20 L 0,60"
          stroke="#4299e1"
          strokeWidth={3}
          fill="none"
          className="flow-line"
        />
        <Path
          d="M 20,20 L 60,60"
          stroke="#4299e1"
          strokeWidth={3}
          fill="none"
          className="flow-line"
        />
        <Path
          d="M -20,20 L -60,60"
          stroke="#4299e1"
          strokeWidth={3}
          fill="none"
          className="flow-line"
        />
      </G>
      <G transform="translate(-130, -100)">
        <Rect
          x={-30}
          y={-20}
          width={60}
          height={40}
          rx={5}
          fill="#4299e1"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          className="pulse"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"SERVER 1"}
        </Text>
      </G>
      <G transform="translate(-60, -100)">
        <Rect
          x={-30}
          y={-20}
          width={60}
          height={40}
          rx={5}
          fill="#4299e1"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          className="pulse"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"SERVER 2"}
        </Text>
      </G>
      <G transform="translate(10, -100)">
        <Rect
          x={-30}
          y={-20}
          width={60}
          height={40}
          rx={5}
          fill="#4299e1"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          className="pulse"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={10}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"SERVER 3"}
        </Text>
      </G>
      <G transform="translate(130, -100)" className="scale">
        <Rect
          x={-40}
          y={-20}
          width={80}
          height={40}
          rx={5}
          fill="#2c5282"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
        />
        <Text
          x={0}
          y={-5}
          fontFamily="Arial, sans-serif"
          fontSize={9}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"SERVICE"}
        </Text>
        <Text
          x={0}
          y={5}
          fontFamily="Arial, sans-serif"
          fontSize={9}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"DISCOVERY"}
        </Text>
        <Path
          d="M -40,-5 L -80,-20"
          stroke="#4a5568"
          strokeWidth={1}
          strokeDasharray="3,2"
        />
        <Path
          d="M -40,0 L -120,0"
          stroke="#4a5568"
          strokeWidth={1}
          strokeDasharray="3,2"
        />
        <Path
          d="M -40,5 L -80,20"
          stroke="#4a5568"
          strokeWidth={1}
          strokeDasharray="3,2"
        />
      </G>
      <Path
        d="M -130,-60 L -130,-20"
        stroke="#4299e1"
        strokeWidth={3}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M -60,-60 L -60,-20"
        stroke="#4299e1"
        strokeWidth={3}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M 10,-60 L 10,-20"
        stroke="#4299e1"
        strokeWidth={3}
        fill="none"
        className="flow-line"
      />
      <G transform="translate(-200, 0)">
        <G transform="translate(0, 0)" className="scale">
          <Rect
            x={-40}
            y={-20}
            width={80}
            height={40}
            rx={5}
            fill="#2c5282"
            filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          />
          <Text
            x={0}
            y={-5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"AUTH"}
          </Text>
          <Text
            x={0}
            y={5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"SERVICE"}
          </Text>
        </G>
      </G>
      <G transform="translate(-80, 0)">
        <G transform="translate(0, 0)" className="pulse">
          <Rect
            x={-40}
            y={-20}
            width={80}
            height={40}
            rx={5}
            fill="#2c5282"
            filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          />
          <Text
            x={0}
            y={-5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"PAYMENT"}
          </Text>
          <Text
            x={0}
            y={5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"SERVICE"}
          </Text>
        </G>
      </G>
      <G transform="translate(40, 0)">
        <G transform="translate(0, 0)" className="pulse">
          <Rect
            x={-40}
            y={-20}
            width={80}
            height={40}
            rx={5}
            fill="#2c5282"
            filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          />
          <Text
            x={0}
            y={-5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"USER"}
          </Text>
          <Text
            x={0}
            y={5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"SERVICE"}
          </Text>
        </G>
      </G>
      <G transform="translate(160, 0)">
        <G transform="translate(0, 0)" className="scale">
          <Rect
            x={-40}
            y={-20}
            width={80}
            height={40}
            rx={5}
            fill="#2c5282"
            filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
          />
          <Text
            x={0}
            y={-5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"PRODUCT"}
          </Text>
          <Text
            x={0}
            y={5}
            fontFamily="Arial, sans-serif"
            fontSize={9}
            textAnchor="middle"
            dominantBaseline="middle"
            fill="white"
          >
            {"SERVICE"}
          </Text>
        </G>
      </G>
      <G transform="translate(-120, 80)">
        <Rect
          x={-60}
          y={-20}
          width={120}
          height={40}
          rx={5}
          fill="#4a5568"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={12}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="white"
        >
          {"MESSAGE QUEUE"}
        </Text>
        <Line
          x1={-50}
          y1={-10}
          x2={50}
          y2={-10}
          stroke="white"
          strokeWidth={1}
        />
        <Line x1={-50} y1={0} x2={50} y2={0} stroke="white" strokeWidth={1} />
        <Line x1={-50} y1={10} x2={50} y2={10} stroke="white" strokeWidth={1} />
        <Rect
          x={-40}
          y={-5}
          width={10}
          height={10}
          fill="white"
          opacity={0.8}
          className="pulse"
        ></Rect>
        <Rect
          x={-10}
          y={-5}
          width={10}
          height={10}
          fill="white"
          opacity={0.8}
          className="pulse"
        ></Rect>
      </G>
      <G transform="translate(80, 80)" className="pulse">
        <Polygon
          points="-40,-25 0,-40 40,-25 40,25 0,40 -40,25"
          fill="#90cdf4"
          filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
        />
        <Text
          x={0}
          y={0}
          fontFamily="Arial, sans-serif"
          fontSize={12}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="#2d3748"
        >
          {"CACHE"}
        </Text>
      </G>
      <G transform="translate(0, 160)">
        <G transform="translate(-100, 0)">
          <G transform="translate(0, 0)" className="pulse">
            <Path
              d="M -20,-15 C -20,-25 20,-25 20,-15 L 20,15 C 20,25 -20,25 -20,15 Z"
              fill="#4299e1"
              filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
            />
            <Path
              d="M -20,-15 C -20,-5 20,-5 20,-15"
              fill="none"
              stroke="#2c5282"
              strokeWidth={1}
            />
            <Text
              x={0}
              y={5}
              fontFamily="Arial, sans-serif"
              fontSize={10}
              textAnchor="middle"
              dominantBaseline="middle"
              fill="white"
            >
              {"DB 1"}
            </Text>
          </G>
        </G>
        <G transform="translate(0, 0)">
          <G transform="translate(0, 0)" className="pulse">
            <Path
              d="M -20,-15 C -20,-25 20,-25 20,-15 L 20,15 C 20,25 -20,25 -20,15 Z"
              fill="#4299e1"
              filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
            />
            <Path
              d="M -20,-15 C -20,-5 20,-5 20,-15"
              fill="none"
              stroke="#2c5282"
              strokeWidth={1}
            />
            <Text
              x={0}
              y={5}
              fontFamily="Arial, sans-serif"
              fontSize={10}
              textAnchor="middle"
              dominantBaseline="middle"
              fill="white"
            >
              {"DB 2"}
            </Text>
          </G>
        </G>
        <G transform="translate(100, 0)">
          <G transform="translate(0, 0)" className="pulse">
            <Path
              d="M -20,-15 C -20,-25 20,-25 20,-15 L 20,15 C 20,25 -20,25 -20,15 Z"
              fill="#4299e1"
              filter="drop-shadow(0 3px 3px rgba(0,0,0,0.2))"
            />
            <Path
              d="M -20,-15 C -20,-5 20,-5 20,-15"
              fill="none"
              stroke="#2c5282"
              strokeWidth={1}
            />
            <Text
              x={0}
              y={5}
              fontFamily="Arial, sans-serif"
              fontSize={10}
              textAnchor="middle"
              dominantBaseline="middle"
              fill="white"
            >
              {"DB 3"}
            </Text>
          </G>
        </G>
      </G>
      <Path
        d="M -200,20 L -200,50 L -120,50 L -120,60"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M -80,20 L -80,50 L -120,50 L -120,60"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M 40,20 L 40,50 L 80,50 L 80,60"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M 160,20 L 160,50 L 80,50 L 80,60"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M -120,100 L -120,130 L -100,130 L -100,145"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M -120,100 L -120,130 L 0,130 L 0,145"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <Path
        d="M 80,100 L 80,130 L 100,130 L 100,145"
        stroke="#4299e1"
        strokeWidth={2}
        fill="none"
        className="flow-line"
      />
      <G transform="translate(0, -250)">
        <Path
          d="M-250,-20 C-250,-60 -200,-80 -160,-80 C-140,-120 -80,-120 -40,-80 C0,-100 60,-80 80,-40 C120,-60 180,-40 200,-10 C240,-20 280,20 260,60 C280,100 240,140 200,130 C180,170 120,170 100,140 C60,170 0,150 -40,130 C-80,150 -120,150 -160,130 C-200,150 -250,120 -250,80 C-280,60 -280,0 -250,-20 Z"
          fill="#90cdf4"
          fillOpacity={0.3}
          stroke="#4299e1"
          strokeWidth={2}
          strokeDasharray="5,3"
        />
        <Text
          x={0}
          y={30}
          fontFamily="Arial, sans-serif"
          fontSize={18}
          fontWeight="bold"
          textAnchor="middle"
          dominantBaseline="middle"
          fill="#2c5282"
        >
          {"DISTRIBUTED SYSTEM"}
        </Text>
      </G>
    </G>
    <G transform="translate(400, 455)">
      <Text
        x={-70}
        y={0}
        fontFamily="Arial, sans-serif"
        fontSize={24}
        fontWeight="bold"
        textAnchor="middle"
        dominantBaseline="middle"
        fill="#1a202c"
      >
        {"HANDS ON SYSTEM DESIGN COURSE"}
      </Text>
    </G>
  </Svg>
);
export default SVGComponent;
